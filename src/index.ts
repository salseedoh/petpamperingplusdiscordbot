import cron from 'node-cron';
import {
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  Client,
  EmbedBuilder,
  Events,
  GatewayIntentBits,
  MessageFlags,
  PermissionFlagsBits,
  type ButtonInteraction,
  type ChatInputCommandInteraction,
  type Interaction
} from 'discord.js';
import { createClient } from '@supabase/supabase-js';
import { config } from './config.js';

type Question = { id: string; prompt: string; options: string[]; correct_option: number; explanation: string; topic: string | null };
type Session = { id: string; question_id: string; kind: 'trivia' | 'quiz' | 'daily'; guild_id: string; owner_discord_user_id: string | null; quiz_run_id: string | null; daily_date: string | null; expires_at: string | null };

const supabase = createClient(config.supabaseUrl, config.supabaseSecretKey, {
  auth: { autoRefreshToken: false, persistSession: false }
});
const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const letters = ['A', 'B', 'C', 'D'];

function todayCentral(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: config.timezone }).format(new Date());
}

function questionEmbed(question: Question, heading = '🐾 Pet First Aid Question'): EmbedBuilder {
  return new EmbedBuilder()
    .setColor(0x2f855a)
    .setTitle(heading)
    .setDescription(`${question.prompt}\n\n${question.options.map((option, index) => `**${letters[index]}.** ${option}`).join('\n')}\n\nSelect an option below.`);
}

function questionButtons(sessionId: string): ActionRowBuilder<ButtonBuilder> {
  return new ActionRowBuilder<ButtonBuilder>().addComponents(
    ...letters.map((letter, index) => new ButtonBuilder().setCustomId(`answer:${sessionId}:${index}`).setLabel(letter).setStyle(ButtonStyle.Primary))
  );
}

async function activeQuestions(): Promise<Question[]> {
  const { data, error } = await supabase.from('questions').select('*').eq('enabled', true);
  if (error) throw error;
  return (data ?? []) as Question[];
}

function randomQuestion(questions: Question[]): Question {
  return questions[Math.floor(Math.random() * questions.length)];
}

async function createSession(question: Question, kind: Session['kind'], guildId: string, channelId: string, ownerId: string | null, dailyDate: string | null = null, quizRunId: string | null = null): Promise<Session> {
  const { data, error } = await supabase.from('question_sessions').insert({
    question_id: question.id, kind, guild_id: guildId, channel_id: channelId,
    owner_discord_user_id: ownerId, daily_date: dailyDate, quiz_run_id: quizRunId
  }).select().single();
  if (error) throw error;
  return data as Session;
}

async function postDailyQuestion(): Promise<void> {
  const channel = await client.channels.fetch(config.dailyChannelId);
  if (!channel?.isTextBased() || !('send' in channel)) throw new Error('DAILY_CHANNEL_ID must be a text channel.');
  const dailyDate = todayCentral();
  const { data: existing } = await supabase.from('question_sessions').select('id').eq('guild_id', config.guildId).eq('daily_date', dailyDate).maybeSingle();
  if (existing) return;
  const questions = await activeQuestions();
  if (!questions.length) throw new Error('No enabled questions are available for the daily question.');
  const question = randomQuestion(questions);
  const session = await createSession(question, 'daily', config.guildId, config.dailyChannelId, null, dailyDate);
  await channel.send({ embeds: [questionEmbed(question, '🐾 Daily Pet First Aid Question')], components: [questionButtons(session.id)] });
}

async function resetMissedStreaks(): Promise<void> {
  const today = todayCentral();
  const yesterday = new Date(`${today}T12:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const previousDate = yesterday.toISOString().slice(0, 10);
  const { error } = await supabase.from('employee_profiles').update({ daily_streak: 0, updated_at: new Date().toISOString() }).lt('last_daily_date', previousDate).gt('daily_streak', 0);
  if (error) throw error;
}

function isAdmin(interaction: ChatInputCommandInteraction): boolean {
  return interaction.memberPermissions?.has(PermissionFlagsBits.Administrator) ?? false;
}

async function awardAnswer(session: Session, question: Question, interaction: ButtonInteraction, selected: number): Promise<{ correct: boolean; alreadyAnswered: boolean }> {
  if (session.owner_discord_user_id && session.owner_discord_user_id !== interaction.user.id) {
    await interaction.reply({ content: 'This question belongs to another employee.', ephemeral: true });
    return { correct: false, alreadyAnswered: true };
  }
  if (session.kind === 'daily' && session.daily_date !== todayCentral()) {
    await interaction.reply({ content: 'This question has expired.', ephemeral: true });
    return { correct: false, alreadyAnswered: true };
  }
  const correct = selected === question.correct_option;
  const { error: answerError } = await supabase.from('question_answers').insert({
    session_id: session.id, discord_user_id: interaction.user.id, selected_option: selected,
    is_correct: correct, points_awarded: correct ? 10 : 0
  });
  if (answerError) {
    if (answerError.code === '23505') await interaction.reply({ content: 'You have already answered this question.', ephemeral: true });
    else throw answerError;
    return { correct, alreadyAnswered: true };
  }

  const { data: profile } = await supabase.from('employee_profiles').select('*').eq('discord_user_id', interaction.user.id).maybeSingle();
  const dailyDate = session.daily_date;
  let streak = profile?.daily_streak ?? 0;
  if (dailyDate) {
    if (correct) {
      const prior = new Date(`${dailyDate}T12:00:00Z`);
      prior.setUTCDate(prior.getUTCDate() - 1);
      streak = profile?.last_daily_date === prior.toISOString().slice(0, 10) ? streak + 1 : 1;
    } else streak = 0;
  }
  const { error: profileError } = await supabase.from('employee_profiles').upsert({
    discord_user_id: interaction.user.id,
    display_name: interaction.user.globalName ?? interaction.user.username,
    total_points: (profile?.total_points ?? 0) + (correct ? 10 : 0),
    daily_streak: streak,
    last_daily_date: dailyDate ?? profile?.last_daily_date ?? null,
    updated_at: new Date().toISOString()
  });
  if (profileError) throw profileError;
  return { correct, alreadyAnswered: false };
}

async function answerButton(interaction: ButtonInteraction): Promise<void> {
  const [, sessionId, choiceText] = interaction.customId.split(':');
  const selected = Number(choiceText);
  const { data: sessionData, error: sessionError } = await supabase.from('question_sessions').select('*').eq('id', sessionId).single();
  if (sessionError || !sessionData) throw new Error('Question session was not found.');
  const session = sessionData as Session;
  const { data: questionData, error: questionError } = await supabase.from('questions').select('*').eq('id', session.question_id).single();
  if (questionError || !questionData) throw new Error('Question was not found.');
  const question = questionData as Question;
  const result = await awardAnswer(session, question, interaction, selected);
  if (result.alreadyAnswered) return;
  const resultEmbed = new EmbedBuilder()
    .setColor(result.correct ? 0x38a169 : 0xe53e3e)
    .setTitle(result.correct ? '✅ Correct!' : '❌ Not quite')
    .setDescription(`**${letters[question.correct_option]} — ${question.options[question.correct_option]}**\n\n**Why:** ${question.explanation}${result.correct ? '\n\n+10 points' : ''}`);
  if (session.kind === 'quiz' && session.quiz_run_id) {
    const { data: run, error: runError } = await supabase.from('quiz_runs').select('*').eq('id', session.quiz_run_id).single();
    if (runError || !run) throw new Error('Quiz run was not found.');
    const nextIndex = run.current_index + 1;
    const correctCount = run.correct_count + (result.correct ? 1 : 0);
    const questionIds = run.question_ids as string[];
    if (nextIndex >= questionIds.length) {
      const { error } = await supabase.from('quiz_runs').update({ current_index: nextIndex, correct_count: correctCount, completed_at: new Date().toISOString() }).eq('id', run.id);
      if (error) throw error;
      resultEmbed.addFields({ name: 'Quiz complete', value: `You answered **${correctCount}/10** correctly and earned **${correctCount * 10} points**.` });
      await interaction.reply({ embeds: [resultEmbed], ephemeral: true });
      return;
    }
    const { data: nextQuestionData, error: nextQuestionError } = await supabase.from('questions').select('*').eq('id', questionIds[nextIndex]).single();
    if (nextQuestionError || !nextQuestionData) throw new Error('Next quiz question was not found.');
    const { error: updateError } = await supabase.from('quiz_runs').update({ current_index: nextIndex, correct_count: correctCount }).eq('id', run.id);
    if (updateError) throw updateError;
    const nextQuestion = nextQuestionData as Question;
    const nextSession = await createSession(nextQuestion, 'quiz', session.guild_id, interaction.channelId, interaction.user.id, null, run.id);
    await interaction.reply({ embeds: [resultEmbed], ephemeral: true });
    await interaction.followUp({ embeds: [questionEmbed(nextQuestion, `🐾 Quiz Question ${nextIndex + 1} of 10`)], components: [questionButtons(nextSession.id)], ephemeral: true });
    return;
  }
  await interaction.reply({ embeds: [resultEmbed], ephemeral: session.kind !== 'daily' });
}

async function startTrivia(interaction: ChatInputCommandInteraction): Promise<void> {
  const questions = await activeQuestions();
  if (!questions.length) return void await interaction.editReply({ content: 'There are no active questions yet.' });
  const question = randomQuestion(questions);
  const session = await createSession(question, 'trivia', interaction.guildId!, interaction.channelId, interaction.user.id);
  await interaction.editReply({ embeds: [questionEmbed(question)], components: [questionButtons(session.id)] });
}

async function startQuiz(interaction: ChatInputCommandInteraction): Promise<void> {
  const questions = await activeQuestions();
  if (questions.length < 10) return void await interaction.editReply({ content: `A quiz needs at least 10 active questions. There are currently ${questions.length}.` });
  const chosen = [...questions].sort(() => Math.random() - 0.5).slice(0, 10);
  const { data: run, error } = await supabase.from('quiz_runs').insert({ discord_user_id: interaction.user.id, guild_id: interaction.guildId, question_ids: chosen.map(question => question.id) }).select().single();
  if (error) throw error;
  const session = await createSession(chosen[0], 'quiz', interaction.guildId!, interaction.channelId, interaction.user.id, null, run.id);
  await interaction.editReply({ embeds: [questionEmbed(chosen[0], '🐾 Quiz Question 1 of 10')], components: [questionButtons(session.id)] });
}

async function leaderboard(interaction: ChatInputCommandInteraction): Promise<void> {
  const { data, error } = await supabase.from('employee_profiles').select('display_name,total_points,daily_streak').order('total_points', { ascending: false }).limit(10);
  if (error) throw error;
  const text = data?.length ? data.map((row, index) => `**${index + 1}.** ${row.display_name} — ${row.total_points} points (${row.daily_streak}-day streak)`).join('\n') : 'No points have been earned yet.';
  await interaction.editReply({ embeds: [new EmbedBuilder().setColor(0xd69e2e).setTitle('🏆 Leaderboard').setDescription(text)] });
}

async function learn(interaction: ChatInputCommandInteraction): Promise<void> {
  let query = supabase.from('training_cards').select('*').eq('enabled', true);
  const topic = interaction.options.getString('topic');
  if (topic) query = query.ilike('topic', `%${topic}%`);
  const { data, error } = await query;
  if (error) throw error;
  if (!data?.length) return void await interaction.editReply({ content: 'No active training cards match that topic.' });
  const card = data[Math.floor(Math.random() * data.length)] as { title: string; warning_signs: string[]; first_steps: string[]; body: string | null };
  await interaction.editReply({ embeds: [new EmbedBuilder().setColor(0x3182ce).setTitle(`📘 ${card.title}`).addFields(
    { name: 'Warning signs', value: card.warning_signs.map(item => `• ${item}`).join('\n') || '—' },
    { name: 'First steps', value: card.first_steps.map(item => `• ${item}`).join('\n') || '—' }
  ).setDescription(card.body ?? null)] });
}

async function adminCommand(interaction: ChatInputCommandInteraction): Promise<void> {
  if (!isAdmin(interaction)) return void await interaction.editReply({ content: 'Administrator permission is required for this command.' });
  if (interaction.commandName === 'addquestion') {
    const options = ['a', 'b', 'c', 'd'].map(name => interaction.options.getString(name, true));
    const { data, error } = await supabase.from('questions').insert({ prompt: interaction.options.getString('prompt', true), options, correct_option: interaction.options.getInteger('correct', true) - 1, explanation: interaction.options.getString('why', true), topic: interaction.options.getString('topic') }).select('id').single();
    if (error) throw error;
    return void await interaction.editReply({ content: `Question added: \`${data.id}\`` });
  }
  if (interaction.commandName === 'editquestion') {
    const changes = Object.fromEntries([['prompt', interaction.options.getString('prompt')], ['explanation', interaction.options.getString('why')], ['topic', interaction.options.getString('topic')]].filter(([, value]) => value !== null));
    if (!Object.keys(changes).length) return void await interaction.editReply({ content: 'Provide at least one replacement value.' });
    const { error } = await supabase.from('questions').update(changes).eq('id', interaction.options.getString('id', true));
    if (error) throw error;
    return void await interaction.editReply({ content: 'Question updated.' });
  }
  if (interaction.commandName === 'disablequestion') {
    const { error } = await supabase.from('questions').update({ enabled: false }).eq('id', interaction.options.getString('id', true));
    if (error) throw error;
    return void await interaction.editReply({ content: 'Question disabled.' });
  }
  if (interaction.commandName === 'reset_scores') {
    if (interaction.options.getString('confirm', true) !== 'RESET') return void await interaction.editReply({ content: 'Nothing changed. Type `RESET` exactly to confirm.' });
    const { error } = await supabase.from('employee_profiles').update({ total_points: 0, daily_streak: 0, last_daily_date: null, updated_at: new Date().toISOString() }).neq('discord_user_id', '');
    if (error) throw error;
    return void await interaction.editReply({ content: 'All employee scores and streaks were reset.' });
  }
  if (interaction.commandName === 'employee_stats') {
    const employee = interaction.options.getUser('employee');
    let query = supabase.from('employee_profiles').select('*');
    if (employee) query = query.eq('discord_user_id', employee.id);
    const { data, error } = await query.order('total_points', { ascending: false }).limit(employee ? 1 : 25);
    if (error) throw error;
    const text = data?.length ? data.map(row => `**${row.display_name}** — ${row.total_points} points, ${row.daily_streak}-day streak`).join('\n') : 'No employee data yet.';
    return void await interaction.editReply({ embeds: [new EmbedBuilder().setTitle('Employee stats').setDescription(text)] });
  }
  const { count, error } = await supabase.from('question_answers').select('*', { count: 'exact', head: true });
  if (error) throw error;
  await interaction.editReply({ content: `Training activity: ${count ?? 0} submitted answers.` });
}

async function handleInteraction(interaction: Interaction): Promise<void> {
  try {
    if (interaction.isButton() && interaction.customId.startsWith('answer:')) await answerButton(interaction);
    if (!interaction.isChatInputCommand()) return;
    if (!interaction.inGuild()) return void await interaction.reply({ content: 'This bot is available only in the employee server.', ephemeral: true });
    const privateCommands = new Set(['quiz', 'addquestion', 'editquestion', 'disablequestion', 'trainingreport', 'employee_stats', 'reset_scores']);
    await interaction.deferReply({ flags: privateCommands.has(interaction.commandName) ? MessageFlags.Ephemeral : undefined });
    if (interaction.commandName === 'trivia') await startTrivia(interaction);
    else if (interaction.commandName === 'quiz') await startQuiz(interaction);
    else if (interaction.commandName === 'leaderboard') await leaderboard(interaction);
    else if (interaction.commandName === 'learn') await learn(interaction);
    else await adminCommand(interaction);
  } catch (error) {
    console.error(error);
    if (interaction.isRepliable() && interaction.deferred) await interaction.editReply({ content: 'Something went wrong. Please try again or ask an administrator to check the bot log.' });
    else if (interaction.isRepliable() && !interaction.replied) await interaction.reply({ content: 'Something went wrong. Please try again or ask an administrator to check the bot log.', ephemeral: true });
  }
}

client.once(Events.ClientReady, readyClient => {
  console.log(`Logged in as ${readyClient.user.tag}.`);
  void resetMissedStreaks().catch(error => console.error('Could not reset missed streaks:', error));
  cron.schedule(config.cron, () => void postDailyQuestion().catch(error => console.error('Could not post daily question:', error)), { timezone: config.timezone });
  cron.schedule('0 0 * * *', () => void resetMissedStreaks().catch(error => console.error('Could not reset missed streaks:', error)), { timezone: config.timezone });
});
client.on('interactionCreate', interaction => void handleInteraction(interaction));
client.login(config.discordToken);
