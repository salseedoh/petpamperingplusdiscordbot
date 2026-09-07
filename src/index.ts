import cron from 'node-cron';
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  ActionRowBuilder,
  AttachmentBuilder,
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

type Question = { id: string; prompt: string; options: string[]; correct_option: number; explanation: string; topic: string | null; image_filename: string | null };
type Session = { id: string; question_id: string; kind: 'trivia' | 'quiz' | 'daily' | 'test'; guild_id: string; channel_id: string; message_id: string | null; owner_discord_user_id: string | null; quiz_run_id: string | null; daily_date: string | null; expires_at: string | null };
type PrivateInteraction = ChatInputCommandInteraction | ButtonInteraction;
type AwardResult = { correct: boolean; alreadyAnswered: boolean; dailyStreak: number | null; correctAnswerMilestone: number | null; streakMilestone: number | null };
type HealthStatus = {
  state: 'starting' | 'online' | 'reconnecting';
  lastUpdated: string;
  lastHeartbeat: string;
  lastDiscordConnection: string | null;
  lastSupabaseSuccess: string | null;
  lastDailyPost: string | null;
  lastDailyCleanup: string | null;
  lastError: string | null;
};

const supabase = createClient(config.supabaseUrl, config.supabaseSecretKey, {
  auth: { autoRefreshToken: false, persistSession: false }
});
const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const letters = ['A', 'B', 'C', 'D', 'E'];
const QUESTION_EXPIRY_MS = 10 * 60 * 1000;
const VIEW_EXPIRY_MS = 5 * 60 * 1000;
const SHORT_EXPIRY_MS = 60 * 1000;
const QUIZ_QUESTION_COUNT = 5;
const questionImageDirectory = fileURLToPath(new URL('../assets/questions/', import.meta.url));
const runtimeDirectory = fileURLToPath(new URL('../logs/', import.meta.url));
const logFile = join(runtimeDirectory, 'pet-first-aid-bot.log');
const healthFile = join(runtimeDirectory, 'bot-health.json');
const healthPageFile = join(runtimeDirectory, 'bot-health.html');
const alertCooldowns = new Map<string, number>();
let schedulesRegistered = false;

mkdirSync(runtimeDirectory, { recursive: true });

const originalConsole = {
  log: console.log.bind(console),
  warn: console.warn.bind(console),
  error: console.error.bind(console)
};

function logValue(value: unknown): string {
  if (typeof value === 'string') return value;
  try { return JSON.stringify(value); } catch { return String(value); }
}

function writeLog(level: 'INFO' | 'WARN' | 'ERROR', values: unknown[]): void {
  try {
    appendFileSync(logFile, `[${new Date().toISOString()}] ${level} ${values.map(logValue).join(' ')}\n`);
  } catch {
    // Logging must never prevent the bot from operating.
  }
}

console.log = (...values: unknown[]) => { originalConsole.log(...values); writeLog('INFO', values); };
console.warn = (...values: unknown[]) => { originalConsole.warn(...values); writeLog('WARN', values); };
console.error = (...values: unknown[]) => { originalConsole.error(...values); writeLog('ERROR', values); };

function loadHealth(): HealthStatus {
  try {
    return JSON.parse(readFileSync(healthFile, 'utf8')) as HealthStatus;
  } catch {
    const now = new Date().toISOString();
    return { state: 'starting', lastUpdated: now, lastHeartbeat: now, lastDiscordConnection: null, lastSupabaseSuccess: null, lastDailyPost: null, lastDailyCleanup: null, lastError: null };
  }
}

const previousHealth = loadHealth();
const wasUnhealthyAtStartup = Date.now() - Date.parse(previousHealth.lastHeartbeat) > 10 * 60 * 1000;
let health = previousHealth;

function escapeHtml(value: string | null): string {
  return (value ?? 'Not yet').replace(/[&<>'"]/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character] ?? character);
}

function writeHealthPage(): void {
  const rows = [
    ['Bot state', health.state],
    ['Last heartbeat', health.lastHeartbeat],
    ['Last Discord connection', health.lastDiscordConnection],
    ['Last successful Supabase request', health.lastSupabaseSuccess],
    ['Last daily post', health.lastDailyPost],
    ['Last daily cleanup', health.lastDailyCleanup],
    ['Last warning/error', health.lastError]
  ].map(([label, value]) => `<tr><th>${escapeHtml(label)}</th><td>${escapeHtml(value)}</td></tr>`).join('');
  const color = health.state === 'online' ? '#237804' : health.state === 'reconnecting' ? '#ad6800' : '#a8071a';
  writeFileSync(healthPageFile, `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="60"><title>Pet First Aid Bot Health</title><style>body{font-family:Segoe UI,Arial,sans-serif;margin:32px;background:#f7f9fc;color:#1f2937}main{max-width:760px;background:white;border-radius:12px;padding:28px;box-shadow:0 2px 12px #0001}h1{margin-top:0}.state{color:${color};font-weight:700;text-transform:capitalize}table{border-collapse:collapse;width:100%}th,td{padding:12px;text-align:left;border-bottom:1px solid #e5e7eb}th{width:38%;color:#4b5563}p{color:#6b7280}</style></head><body><main><h1>Pet First Aid Bot Health</h1><p>Refreshes every minute while this page is open. If the last heartbeat is more than 10 minutes old, the bot may be offline.</p><p class="state">Status: ${escapeHtml(health.state)}</p><table>${rows}</table></main></body></html>`);
}

function updateHealth(change: Partial<HealthStatus>): void {
  const now = new Date().toISOString();
  health = { ...health, ...change, lastUpdated: now };
  writeFileSync(healthFile, JSON.stringify(health, null, 2));
  writeHealthPage();
}

updateHealth({ state: 'starting', lastHeartbeat: new Date().toISOString() });

function todayCentral(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: config.timezone }).format(new Date());
}

function previousCentralDate(): string {
  const date = new Date(`${todayCentral()}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

function currentCentralMonth(): string {
  return todayCentral().slice(0, 7);
}

function currentCentralMonthLabel(): string {
  return new Intl.DateTimeFormat('en-US', { timeZone: config.timezone, month: 'long', year: 'numeric' }).format(new Date());
}

function centralMonthBounds(): { start: string; end: string } {
  const [yearText, monthText] = currentCentralMonth().split('-');
  const year = Number(yearText);
  const monthIndex = Number(monthText) - 1;
  // The database query intentionally includes a small UTC buffer. Results are
  // then filtered using the configured Central timezone, including DST changes.
  return {
    start: new Date(Date.UTC(year, monthIndex, 1)).toISOString(),
    end: new Date(Date.UTC(year, monthIndex + 1, 2)).toISOString()
  };
}

function monthCentral(timestamp: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: config.timezone }).format(new Date(timestamp)).slice(0, 7);
}

function questionEmbed(question: Question, heading = '🐾 Pet First Aid Question'): EmbedBuilder {
  const embed = new EmbedBuilder()
    .setColor(0x2f855a)
    .setTitle(heading)
    .setDescription(`${question.prompt}\n\n${question.options.map((option, index) => `**${letters[index]}.** ${option}`).join('\n')}\n\nSelect an option below.`);
  const image = questionImage(question);
  if (image) embed.setImage(`attachment://${image.filename}`);
  return embed;
}

function questionImage(question: Question): { path: string; filename: string } | null {
  if (!question.image_filename || basename(question.image_filename) !== question.image_filename) return null;
  const path = join(questionImageDirectory, question.image_filename);
  if (!existsSync(path)) {
    console.warn(`Question image is missing: ${question.image_filename}`);
    return null;
  }
  return { path, filename: question.image_filename };
}

function questionFiles(question: Question): AttachmentBuilder[] {
  const image = questionImage(question);
  return image ? [new AttachmentBuilder(image.path, { name: image.filename })] : [];
}

function questionButtons(sessionId: string, optionCount: number, disabled = false): ActionRowBuilder<ButtonBuilder> {
  return new ActionRowBuilder<ButtonBuilder>().addComponents(
    ...letters.slice(0, optionCount).map((letter, index) => new ButtonBuilder().setCustomId(`answer:${sessionId}:${index}`).setLabel(letter).setStyle(ButtonStyle.Primary).setDisabled(disabled))
  );
}

function employeeMenu(): { embeds: EmbedBuilder[]; components: ActionRowBuilder<ButtonBuilder>[] } {
  return {
    embeds: [new EmbedBuilder()
      .setColor(0x3182ce)
      .setTitle('🐾 Pet First Aid Menu')
      .setDescription('Choose an option below. Your result will be visible only to you.')],
    components: [new ActionRowBuilder<ButtonBuilder>().addComponents(
      new ButtonBuilder().setCustomId('menu:trivia').setLabel('Trivia').setStyle(ButtonStyle.Primary),
      new ButtonBuilder().setCustomId('menu:quiz').setLabel('Quiz').setStyle(ButtonStyle.Primary),
      new ButtonBuilder().setCustomId('menu:learn').setLabel('Learn').setStyle(ButtonStyle.Success),
      new ButtonBuilder().setCustomId('menu:leaderboard').setLabel('Leaderboard').setStyle(ButtonStyle.Secondary)
    )]
  };
}

async function activeQuestions(): Promise<Question[]> {
  return await retrySupabase<Question[]>('active questions', () =>
    supabase.from('questions').select('*').eq('enabled', true)
  );
}

function randomQuestion(questions: Question[]): Question {
  return questions[Math.floor(Math.random() * questions.length)];
}

type DailyRotation = { used_question_ids: string[] };

async function nextDailyQuestion(questions: Question[]): Promise<{ question: Question; usedQuestionIds: string[] }> {
  const rotation = await retrySupabase<DailyRotation | null>('daily rotation state', () =>
    supabase.from('daily_question_rotations').select('used_question_ids').eq('guild_id', config.guildId).maybeSingle()
  );
  const activeIds = new Set(questions.map(question => question.id));
  let usedQuestionIds: string[];
  if (rotation) {
    usedQuestionIds = rotation.used_question_ids.filter(questionId => activeIds.has(questionId));
  } else {
    const history = await retrySupabase<Array<{ question_id: string }>>('daily rotation history', () =>
      supabase.from('question_sessions').select('question_id').eq('guild_id', config.guildId).eq('kind', 'daily')
    );
    usedQuestionIds = history.map(session => session.question_id).filter(questionId => activeIds.has(questionId));
  }
  let candidates = questions.filter(question => !usedQuestionIds.includes(question.id));
  if (!candidates.length) {
    // Every active question has appeared: begin a new random rotation.
    usedQuestionIds = [];
    candidates = questions;
  }
  const question = randomQuestion(candidates);
  return { question, usedQuestionIds: [...usedQuestionIds, question.id] };
}

async function saveDailyRotation(usedQuestionIds: string[]): Promise<void> {
  await retrySupabase('save daily rotation state', () =>
    supabase.from('daily_question_rotations').upsert({
      guild_id: config.guildId,
      used_question_ids: usedQuestionIds,
      updated_at: new Date().toISOString()
    }, { onConflict: 'guild_id' })
  );
}

async function createSession(question: Question, kind: Session['kind'], guildId: string, channelId: string, ownerId: string | null, dailyDate: string | null = null, quizRunId: string | null = null): Promise<Session> {
  return await retrySupabase<Session>('create question session', () =>
    supabase.from('question_sessions').insert({
      question_id: question.id, kind, guild_id: guildId, channel_id: channelId,
      owner_discord_user_id: ownerId, daily_date: dailyDate, quiz_run_id: quizRunId
    }).select().single()
  );
}

function wait(milliseconds: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function errorDetails(error: unknown): Record<string, unknown> {
  if (!error || typeof error !== 'object') return { message: String(error) };
  const value = error as Record<string, unknown>;
  const cause = value.cause && typeof value.cause === 'object' ? value.cause as Record<string, unknown> : null;
  return {
    name: value.name,
    message: value.message,
    code: value.code,
    status: value.status,
    details: value.details,
    hint: value.hint,
    cause: cause?.message
  };
}

function isUnknownDiscordMessage(error: unknown): boolean {
  return !!error && typeof error === 'object' && (error as { code?: unknown }).code === 10008;
}

function deleteReplyAfter(interaction: { deleteReply: (message?: string) => Promise<unknown> }, milliseconds: number, messageId?: string): void {
  const timer = setTimeout(() => {
    void retry('Private response cleanup', () => interaction.deleteReply(messageId), 3, attempt => attempt * 15_000)
      .catch(error => console.warn('Could not remove an expired private response after retries:', errorDetails(error)));
  }, milliseconds);
  timer.unref();
}

function isRetriableError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return true;
  const { status, code } = error as { status?: unknown; code?: unknown };
  // Client-side Discord and Supabase errors (such as missing permissions) will
  // not succeed after a retry. Network failures and server errors may recover.
  return code === 'PGRST303' || typeof status !== 'number' || status === 408 || status === 429 || status >= 500;
}

async function retry<T>(label: string, operation: () => Promise<T>, attempts = 4, retryDelay: (attempt: number) => number = attempt => attempt * 60_000): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      updateHealth({ lastError: `${label}: ${String(errorDetails(error).message ?? 'request failed')}` });
      if (attempt === attempts || !isRetriableError(error)) break;
      const delay = retryDelay(attempt);
      console.warn(`${label} failed (attempt ${attempt}/${attempts}); retrying in ${Math.ceil(delay / 1000)} second(s).`, errorDetails(error));
      await wait(delay);
    }
  }
  throw lastError;
}

async function retrySupabase<T>(label: string, operation: () => PromiseLike<{ data: T | null; error: unknown }>): Promise<T> {
  const data = await retry(`Supabase request: ${label}`, async () => {
    const { data, error } = await operation();
    if (error) {
      console.warn(`Supabase request failed: ${label}`, errorDetails(error));
      throw error;
    }
    return data as T;
  }, 3, attempt => attempt === 1 ? 1_000 : 3_000);
  updateHealth({ lastSupabaseSuccess: new Date().toISOString() });
  return data;
}

async function notifyBotInfo(key: string, title: string, message: string, color = 0xd69e2e): Promise<void> {
  if (!config.botInfoChannelId || !client.isReady()) return;
  const lastSent = alertCooldowns.get(key) ?? 0;
  if (Date.now() - lastSent < 30 * 60 * 1000) return;
  alertCooldowns.set(key, Date.now());
  try {
    await retry(`Bot-info notice: ${key}`, async () => {
      const channel = await client.channels.fetch(config.botInfoChannelId!);
      if (!channel?.isTextBased() || !('send' in channel)) throw new Error('BOT_INFO_CHANNEL_ID must be a text channel.');
      await channel.send({ embeds: [new EmbedBuilder().setColor(color).setTitle(title).setDescription(message).setTimestamp()] });
    }, 3, attempt => attempt * 15_000);
  } catch (error) {
    console.warn('Could not send a bot-info notice:', errorDetails(error));
  }
}

async function postDailyQuestion(): Promise<boolean> {
  const channel = await retry('Fetch daily channel', () => client.channels.fetch(config.dailyChannelId), 3, attempt => attempt * 15_000);
  if (!channel?.isTextBased() || !('send' in channel)) throw new Error('DAILY_CHANNEL_ID must be a text channel.');
  const dailyDate = todayCentral();
  const existing = await retrySupabase<Session | null>('today\'s daily session', () =>
    supabase.from('question_sessions').select('*').eq('guild_id', config.guildId).eq('daily_date', dailyDate).maybeSingle()
  );

  let session: Session;
  let question: Question;
  if (existing) {
    session = existing;
    if (session.message_id) return false;
    question = await retrySupabase<Question>('saved daily question', () =>
      supabase.from('questions').select('*').eq('id', session.question_id).single()
    );
  } else {
    const questions = await activeQuestions();
    if (!questions.length) throw new Error('No enabled questions are available for the daily question.');
    const dailyChoice = await nextDailyQuestion(questions);
    question = dailyChoice.question;
    session = await createSession(question, 'daily', config.guildId, config.dailyChannelId, null, dailyDate);
    await saveDailyRotation(dailyChoice.usedQuestionIds);
  }
  const message = await retry<{ id: string }>('Send daily question', async () => {
    const sent = await channel.send({ embeds: [questionEmbed(question, '🐾 Daily Pet First Aid Question')], components: [questionButtons(session.id, question.options.length)], files: questionFiles(question) });
    return { id: sent.id };
  }, 3, attempt => attempt * 15_000);
  await retrySupabase<void>('save daily message ID', () =>
    supabase.from('question_sessions').update({ message_id: message.id, channel_id: config.dailyChannelId }).eq('id', session.id)
  );
  updateHealth({ lastDailyPost: new Date().toISOString() });
  return true;
}

async function ensureDailyQuestion(reason: string): Promise<boolean> {
  try {
    const posted = await retry(`Daily question (${reason})`, () => postDailyQuestion());
    if (posted) {
      console.log(`Posted daily question (${reason}).`);
      if (reason !== 'scheduled time') await notifyBotInfo('daily-recovered', '✅ Daily question posted', `The daily question was posted through **${reason}**.`, 0x237804);
    }
    return posted;
  } catch (error) {
    await notifyBotInfo('daily-post-failed', '⚠️ Daily question was not posted', `The bot could not post today’s daily question during **${reason}**. It will keep trying while it is online.\n\nError: ${String(errorDetails(error).message ?? 'Unknown error')}`);
    throw error;
  }
}

async function expiredDailySessions(): Promise<Session[]> {
  return await retrySupabase<Session[]>('expired daily sessions', () =>
    supabase.from('question_sessions').select('*').eq('kind', 'daily').lt('daily_date', todayCentral()).not('message_id', 'is', null)
  );
}

async function markExpiredDailyMessageCleaned(session: Session): Promise<void> {
  try {
    await retrySupabase<void>('clear already-removed daily message', () =>
      supabase.from('question_sessions').update({ message_id: null }).eq('id', session.id)
    );
    updateHealth({ lastDailyCleanup: new Date().toISOString() });
    console.log(`Expired daily message was already gone; cleared its stored message ID (${session.id}).`);
  } catch (error) {
    // The Discord message is already gone. Retaining the ID is harmless; a
    // later health check can attempt to clear it again if Supabase was offline.
    console.warn('Could not clear the stored ID for an already-removed daily message:', errorDetails(error));
  }
}

async function disableExpiredDailyQuestions(): Promise<void> {
  for (const session of await expiredDailySessions()) {
    try {
      await retry('Disable expired daily question', async () => {
        const channel = await client.channels.fetch(session.channel_id);
        if (!channel?.isTextBased() || !('messages' in channel)) return;
        const message = await channel.messages.fetch(session.message_id!);
        await message.edit({ components: [] });
      }, 3, attempt => attempt * 15_000);
    } catch (error) {
      if (isUnknownDiscordMessage(error)) {
        await markExpiredDailyMessageCleaned(session);
        continue;
      }
      console.error('Could not disable expired daily question after retries:', errorDetails(error));
      await notifyBotInfo('daily-disable-failed', '⚠️ Daily question buttons could not be disabled', `An expired daily question still has active buttons.\n\nError: ${String(errorDetails(error).message ?? 'Unknown error')}`);
    }
  }
}

async function deleteExpiredDailyQuestions(): Promise<void> {
  for (const session of await expiredDailySessions()) {
    try {
      await retry('Delete expired daily question', async () => {
        const channel = await client.channels.fetch(session.channel_id);
        if (!channel?.isTextBased() || !('messages' in channel)) return;
        const message = await channel.messages.fetch(session.message_id!);
        await message.delete();
      }, 3, attempt => attempt * 15_000);
      updateHealth({ lastDailyCleanup: new Date().toISOString() });
    } catch (error) {
      if (isUnknownDiscordMessage(error)) {
        await markExpiredDailyMessageCleaned(session);
        continue;
      }
      console.error('Could not delete expired daily question after retries:', errorDetails(error));
      await notifyBotInfo('daily-delete-failed', '⚠️ Expired daily question was not deleted', `The bot will try again during its next health check.\n\nError: ${String(errorDetails(error).message ?? 'Unknown error')}`);
    }
  }
}

async function resetMissedStreaks(): Promise<void> {
  const today = todayCentral();
  const yesterday = new Date(`${today}T12:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const previousDate = yesterday.toISOString().slice(0, 10);
  await retrySupabase<void>('reset missed daily streaks', () =>
    supabase.from('employee_profiles').update({ daily_streak: 0, updated_at: new Date().toISOString() }).lt('last_daily_date', previousDate).gt('daily_streak', 0)
  );
}

function isAdmin(interaction: ChatInputCommandInteraction): boolean {
  return interaction.memberPermissions?.has(PermissionFlagsBits.Administrator) ?? false;
}

async function correctAnswerCount(discordUserId: string): Promise<number> {
  const result = await retry('Supabase request: correct-answer count', async () => {
    const { count, error } = await supabase.from('question_answers').select('*', { count: 'exact', head: true }).eq('discord_user_id', discordUserId).eq('is_correct', true);
    if (error) {
      console.warn('Supabase request failed: correct-answer count', errorDetails(error));
      throw error;
    }
    return count ?? 0;
  }, 3, attempt => attempt === 1 ? 1_000 : 3_000);
  return result;
}

async function claimMilestone(discordUserId: string, kind: 'correct_answers' | 'daily_streak', milestoneValue: number): Promise<boolean> {
  const data = await retrySupabase<Array<{ milestone_value: number }>>('claim milestone', () =>
    supabase
      .from('employee_milestones')
      .upsert({ discord_user_id: discordUserId, kind, milestone_value: milestoneValue }, { onConflict: 'discord_user_id,kind,milestone_value', ignoreDuplicates: true })
      .select('milestone_value')
  );
  return (data?.length ?? 0) > 0;
}

async function awardAnswer(session: Session, question: Question, interaction: ButtonInteraction, selected: number): Promise<AwardResult> {
  if (session.owner_discord_user_id && session.owner_discord_user_id !== interaction.user.id) {
    await interaction.editReply({ content: 'This question belongs to another employee.' });
    return { correct: false, alreadyAnswered: true, dailyStreak: null, correctAnswerMilestone: null, streakMilestone: null };
  }
  if (session.kind === 'daily' && session.daily_date !== todayCentral()) {
    await interaction.editReply({ content: 'This question has expired.' });
    return { correct: false, alreadyAnswered: true, dailyStreak: null, correctAnswerMilestone: null, streakMilestone: null };
  }
  const correct = selected === question.correct_option;
  if (session.kind === 'test') {
    return { correct, alreadyAnswered: false, dailyStreak: null, correctAnswerMilestone: null, streakMilestone: null };
  }
  const award = await retrySupabase<{ already_answered: boolean; is_correct: boolean; daily_streak: number }[]>('record answer and update score', () =>
    supabase.rpc('award_question_answer', {
      p_session_id: session.id,
      p_discord_user_id: interaction.user.id,
      p_display_name: interaction.user.globalName ?? interaction.user.username,
      p_selected_option: selected
    })
  );
  const recorded = award[0];
  if (!recorded) throw new Error('The answer could not be recorded.');
  if (recorded.already_answered) {
    await interaction.editReply({ content: 'You have already answered this question.' });
    return { correct: recorded.is_correct, alreadyAnswered: true, dailyStreak: null, correctAnswerMilestone: null, streakMilestone: null };
  }
  const dailyDate = session.daily_date;
  const streak = recorded.daily_streak;
  let correctAnswerMilestone: number | null = null;
  let streakMilestone: number | null = null;
  if (recorded.is_correct) {
    const totalCorrect = await correctAnswerCount(interaction.user.id);
    const completedCorrectMilestone = Math.floor(totalCorrect / 25) * 25;
    if (completedCorrectMilestone > 0 && await claimMilestone(interaction.user.id, 'correct_answers', completedCorrectMilestone)) {
      correctAnswerMilestone = completedCorrectMilestone;
    }
    const completedStreakMilestone = Math.floor(streak / 7) * 7;
    if (dailyDate && completedStreakMilestone > 0 && await claimMilestone(interaction.user.id, 'daily_streak', completedStreakMilestone)) {
      streakMilestone = completedStreakMilestone;
    }
  }
  return { correct: recorded.is_correct, alreadyAnswered: false, dailyStreak: dailyDate ? streak : null, correctAnswerMilestone, streakMilestone };
}

async function answerButton(interaction: ButtonInteraction): Promise<void> {
  await interaction.deferReply({ flags: MessageFlags.Ephemeral });
  const [, sessionId, choiceText] = interaction.customId.split(':');
  const selected = Number(choiceText);
  const session = await retrySupabase<Session>('answer: question session', () =>
    supabase.from('question_sessions').select('*').eq('id', sessionId).single()
  );
  const question = await retrySupabase<Question>('answer: question', () =>
    supabase.from('questions').select('*').eq('id', session.question_id).single()
  );
  const result = await awardAnswer(session, question, interaction, selected);
  if (result.alreadyAnswered) {
    deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
    return;
  }
  const explanationSection = question.explanation.trim() ? `\n\n**Why:** ${question.explanation}` : '';
  const milestoneSection = [
    result.correctAnswerMilestone !== null ? `🎉 **Learning milestone:** ${result.correctAnswerMilestone} correct answers!` : null,
    result.streakMilestone !== null ? `🔥 **Streak milestone:** ${result.streakMilestone} days!` : null
  ].filter((value): value is string => value !== null).join('\n');
  const resultEmbed = new EmbedBuilder()
    .setColor(result.correct ? 0x38a169 : 0xe53e3e)
    .setTitle(result.correct ? '✅ Correct!' : '❌ Not quite')
    .setDescription(`**${letters[question.correct_option]} — ${question.options[question.correct_option]}**${explanationSection}${session.kind === 'test' ? '\n\nTest mode — no points awarded.' : result.correct ? `\n\n+${session.kind === 'daily' ? 10 : 1} point${session.kind === 'daily' ? 's' : ''}` : ''}${result.dailyStreak !== null ? `\n\n🔥 **Daily streak:** ${result.dailyStreak} day${result.dailyStreak === 1 ? '' : 's'}` : ''}${milestoneSection ? `\n\n${milestoneSection}` : ''}`);
  if (session.kind === 'quiz' && session.quiz_run_id) {
    const { data: run, error: runError } = await supabase.from('quiz_runs').select('*').eq('id', session.quiz_run_id).single();
    if (runError || !run) throw new Error('Quiz run was not found.');
    const nextIndex = run.current_index + 1;
    const correctCount = run.correct_count + (result.correct ? 1 : 0);
    const questionIds = run.question_ids as string[];
    if (nextIndex >= questionIds.length) {
      const { error } = await supabase.from('quiz_runs').update({ current_index: nextIndex, correct_count: correctCount, completed_at: new Date().toISOString() }).eq('id', run.id);
      if (error) throw error;
      resultEmbed.addFields({ name: 'Quiz complete', value: `You answered **${correctCount}/${QUIZ_QUESTION_COUNT}** correctly and earned **${correctCount} point${correctCount === 1 ? '' : 's'}**.` });
      await interaction.editReply({ embeds: [resultEmbed] });
      deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
      return;
    }
    const { data: nextQuestionData, error: nextQuestionError } = await supabase.from('questions').select('*').eq('id', questionIds[nextIndex]).single();
    if (nextQuestionError || !nextQuestionData) throw new Error('Next quiz question was not found.');
    const { error: updateError } = await supabase.from('quiz_runs').update({ current_index: nextIndex, correct_count: correctCount }).eq('id', run.id);
    if (updateError) throw updateError;
    const nextQuestion = nextQuestionData as Question;
    const nextSession = await createSession(nextQuestion, 'quiz', session.guild_id, interaction.channelId, interaction.user.id, null, run.id);
    await interaction.editReply({ embeds: [resultEmbed] });
    const nextQuestionMessage = await interaction.followUp({ embeds: [questionEmbed(nextQuestion, `🐾 Quiz Question ${nextIndex + 1} of ${QUIZ_QUESTION_COUNT}`)], components: [questionButtons(nextSession.id, nextQuestion.options.length)], files: questionFiles(nextQuestion), ephemeral: true });
    deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
    deleteReplyAfter(interaction, QUESTION_EXPIRY_MS, nextQuestionMessage.id);
    return;
  }
  await interaction.editReply({ embeds: [resultEmbed] });
  deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
}

async function startTrivia(interaction: PrivateInteraction): Promise<void> {
  const questions = await activeQuestions();
  if (!questions.length) {
    await interaction.editReply({ content: 'There are no active questions yet.' });
    deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
    return;
  }
  const question = randomQuestion(questions);
  const session = await createSession(question, 'trivia', interaction.guildId!, interaction.channelId, interaction.user.id);
  await interaction.editReply({ embeds: [questionEmbed(question)], components: [questionButtons(session.id, question.options.length)], files: questionFiles(question) });
  deleteReplyAfter(interaction, QUESTION_EXPIRY_MS);
}

async function startQuiz(interaction: PrivateInteraction): Promise<void> {
  const questions = await activeQuestions();
  if (questions.length < QUIZ_QUESTION_COUNT) {
    await interaction.editReply({ content: `A quiz needs at least ${QUIZ_QUESTION_COUNT} active questions. There are currently ${questions.length}.` });
    deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
    return;
  }
  const chosen = [...questions].sort(() => Math.random() - 0.5).slice(0, QUIZ_QUESTION_COUNT);
  const { data: run, error } = await supabase.from('quiz_runs').insert({ discord_user_id: interaction.user.id, guild_id: interaction.guildId, question_ids: chosen.map(question => question.id) }).select().single();
  if (error) throw error;
  const session = await createSession(chosen[0], 'quiz', interaction.guildId!, interaction.channelId, interaction.user.id, null, run.id);
  await interaction.editReply({ embeds: [questionEmbed(chosen[0], `🐾 Quiz Question 1 of ${QUIZ_QUESTION_COUNT}`)], components: [questionButtons(session.id, chosen[0].options.length)], files: questionFiles(chosen[0]) });
  deleteReplyAfter(interaction, QUESTION_EXPIRY_MS);
}

async function dailyTriviaStatus(guildId: string, discordUserId: string): Promise<string> {
  const session = await retrySupabase<{ id: string } | null>('leaderboard: today’s daily session', () =>
    supabase
      .from('question_sessions')
      .select('id')
      .eq('kind', 'daily')
      .eq('guild_id', guildId)
      .eq('daily_date', todayCentral())
      .maybeSingle()
  );
  if (!session) return '⌛ Not posted yet';

  const answer = await retrySupabase<{ id: string } | null>('leaderboard: today’s daily answer', () =>
    supabase
      .from('question_answers')
      .select('id')
      .eq('session_id', session.id)
      .eq('discord_user_id', discordUserId)
      .maybeSingle()
  );
  return answer ? '✅ Completed today' : '⏳ Not completed today';
}

async function leaderboard(interaction: PrivateInteraction): Promise<void> {
  const bounds = centralMonthBounds();
  const [allTimeProfiles, dailyStatus, correctCount, monthlyAnswers, allProfiles] = await Promise.all([
    retrySupabase<Array<{ display_name: string; total_points: number; daily_streak: number }>>('leaderboard: all-time profiles', () =>
      supabase.from('employee_profiles').select('display_name,total_points,daily_streak').order('total_points', { ascending: false }).limit(10)
    ),
    dailyTriviaStatus(interaction.guildId!, interaction.user.id),
    correctAnswerCount(interaction.user.id),
    retrySupabase<Array<{ discord_user_id: string; points_awarded: number; answered_at: string }>>('leaderboard: monthly answers', () =>
      supabase.from('question_answers').select('discord_user_id,points_awarded,answered_at').gte('answered_at', bounds.start).lt('answered_at', bounds.end)
    ),
    retrySupabase<Array<{ discord_user_id: string; display_name: string; daily_streak: number }>>('leaderboard: employee names and streaks', () =>
      supabase.from('employee_profiles').select('discord_user_id,display_name,daily_streak')
    )
  ]);
  const monthlyPoints = new Map<string, number>();
  for (const answer of monthlyAnswers ?? []) {
    if (monthCentral(answer.answered_at) !== currentCentralMonth() || answer.points_awarded <= 0) continue;
    monthlyPoints.set(answer.discord_user_id, (monthlyPoints.get(answer.discord_user_id) ?? 0) + answer.points_awarded);
  }
  const displayNameByUser = new Map((allProfiles ?? []).map(profile => [profile.discord_user_id, profile.display_name]));
  const monthlyText = monthlyPoints.size
    ? [...monthlyPoints.entries()]
      .sort(([, leftPoints], [, rightPoints]) => rightPoints - leftPoints)
      .slice(0, 10)
      .map(([discordUserId, points], index) => `**${index + 1}.** ${displayNameByUser.get(discordUserId) ?? 'Unknown employee'} — ${points} point${points === 1 ? '' : 's'}`)
      .join('\n')
    : 'No points have been earned this month.';
  const currentStreak = (allProfiles ?? []).find(profile => profile.discord_user_id === interaction.user.id)?.daily_streak ?? 0;
  const nextCorrectMilestone = (Math.floor(correctCount / 25) + 1) * 25;
  const nextStreakMilestone = (Math.floor(currentStreak / 7) + 1) * 7;
  const text = allTimeProfiles?.length ? allTimeProfiles.map((row, index) => `**${index + 1}.** ${row.display_name} — ${row.total_points} points (${row.daily_streak}-day streak)`).join('\n') : 'No points have been earned yet.';
  await interaction.editReply({ embeds: [new EmbedBuilder()
    .setColor(0xd69e2e)
    .setTitle('🏆 Leaderboard')
    .setDescription(`**All-time leaderboard**\n${text}`)
    .addFields(
      { name: `Monthly leaderboard — ${currentCentralMonthLabel()}`, value: monthlyText },
      { name: 'Your learning milestones', value: `Correct answers: **${correctCount}** · Next milestone: **${nextCorrectMilestone}**\nDaily streak: **${currentStreak} days** · Next milestone: **${nextStreakMilestone} days**` }
    )
    .addFields({ name: 'Today’s daily trivia', value: dailyStatus })] });
}

async function learn(interaction: PrivateInteraction, topic?: string): Promise<void> {
  const data = await retrySupabase<Array<{ title: string; warning_signs: string[]; first_steps: string[]; body: string | null; sections?: Array<{ heading: string; content: string }> }>>('training cards', () => {
    let query = supabase.from('training_cards').select('*').eq('enabled', true);
    if (topic) query = query.ilike('topic', `%${topic}%`);
    return query;
  });
  if (!data?.length) return void await interaction.editReply({ content: 'No active training cards match that topic.' });
  const card = data[Math.floor(Math.random() * data.length)] as { title: string; warning_signs: string[]; first_steps: string[]; body: string | null; sections?: Array<{ heading: string; content: string }> };
  const sections = card.sections?.filter(section => section.heading && section.content) ?? [];
  const legacySections = [
    { heading: 'Warning signs', content: card.warning_signs.map(item => `• ${item}`).join('\n') },
    { heading: 'First steps', content: card.first_steps.map(item => `• ${item}`).join('\n') }
  ].filter(section => section.content);
  await interaction.editReply({ embeds: [new EmbedBuilder().setColor(0x3182ce).setTitle(`📘 ${card.title}`)
    .setDescription(card.body ?? null)
    .addFields(...(sections.length ? sections : legacySections).map(section => ({ name: section.heading, value: section.content })))] });
}

async function adminCommand(interaction: ChatInputCommandInteraction): Promise<void> {
  if (!isAdmin(interaction)) return void await interaction.editReply({ content: 'Administrator permission is required for this command.' });
  if (interaction.commandName === 'addquestion') {
    const optionA = interaction.options.getString('a', true);
    const optionB = interaction.options.getString('b', true);
    const optionC = interaction.options.getString('c');
    const optionD = interaction.options.getString('d');
    const optionE = interaction.options.getString('e');
    if ((optionC === null) !== (optionD === null) || (optionE !== null && optionD === null)) {
      return void await interaction.editReply({ content: 'Use either 2 choices (A–B), 4 choices (A–D), or 5 choices (A–E).' });
    }
    const options = [optionA, optionB, optionC, optionD, optionE].filter((option): option is string => option !== null);
    const correctOption = interaction.options.getInteger('correct', true) - 1;
    if (correctOption >= options.length) {
      return void await interaction.editReply({ content: 'The correct-answer number must match one of the choices you provided.' });
    }
    const imageFilename = interaction.options.getString('image');
    if (imageFilename && basename(imageFilename) !== imageFilename) {
      return void await interaction.editReply({ content: 'The image must be a filename only, such as `DogAnatomy.png`.' });
    }
    const { data, error } = await supabase.from('questions').insert({ prompt: interaction.options.getString('prompt', true), options, correct_option: correctOption, explanation: interaction.options.getString('why') ?? '', topic: interaction.options.getString('topic'), image_filename: imageFilename }).select('id').single();
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
  if (interaction.commandName === 'postdaily') {
    const posted = await ensureDailyQuestion('administrator request');
    return void await interaction.editReply({ content: posted ? 'Today\'s daily question was posted in the daily channel.' : 'Today already has a daily question.' });
  }
  if (interaction.commandName === 'testquestion') {
    const { data: questionData, error } = await supabase.from('questions').select('*').eq('id', interaction.options.getString('id', true)).single();
    if (error || !questionData) return void await interaction.editReply({ content: 'Question not found. Copy its ID from the Questions table in Supabase.' });
    const question = questionData as Question;
    const session = await createSession(question, 'test', interaction.guildId!, interaction.channelId, interaction.user.id);
    await interaction.editReply({ embeds: [questionEmbed(question, '🧪 Test Question')], components: [questionButtons(session.id, question.options.length)], files: questionFiles(question) });
    deleteReplyAfter(interaction, QUESTION_EXPIRY_MS);
    return;
  }
  if (interaction.commandName === 'postmenu') {
    if (!interaction.channel?.isTextBased() || !('send' in interaction.channel)) {
      return void await interaction.editReply({ content: 'Run this command in a text channel.' });
    }
    await interaction.channel.send(employeeMenu());
    return void await interaction.editReply({ content: 'Employee menu posted. Pin that menu message in this channel so employees can find it easily.' });
  }
  if (interaction.commandName === 'reset_scores') {
    if (interaction.options.getString('confirm', true) !== 'RESET') return void await interaction.editReply({ content: 'Nothing changed. Type `RESET` exactly to confirm.' });
    const { error: answerError } = await supabase.from('question_answers').delete().not('id', 'is', null);
    if (answerError) throw answerError;
    const { error: milestoneError } = await supabase.from('employee_milestones').delete().not('id', 'is', null);
    if (milestoneError) throw milestoneError;
    const { error: quizError } = await supabase.from('quiz_runs').delete().not('id', 'is', null);
    if (quizError) throw quizError;
    const { error: profileError } = await supabase.from('employee_profiles').update({ total_points: 0, daily_streak: 0, last_daily_date: null, updated_at: new Date().toISOString() }).neq('discord_user_id', '');
    if (profileError) throw profileError;
    return void await interaction.editReply({ content: 'Scores, answer history, monthly standings, milestones, and unfinished quizzes were reset.' });
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
    if (interaction.isButton() && interaction.customId.startsWith('answer:')) {
      await answerButton(interaction);
      return;
    }
    if (interaction.isButton() && interaction.customId.startsWith('menu:')) {
      if (!interaction.inGuild()) return void await interaction.reply({ content: 'This menu is available only in the employee server.', ephemeral: true });
      await interaction.deferReply({ flags: MessageFlags.Ephemeral });
      const action = interaction.customId.split(':')[1];
      if (action === 'trivia') {
        await startTrivia(interaction);
      } else if (action === 'quiz') {
        await startQuiz(interaction);
      } else if (action === 'learn') {
        await learn(interaction);
        deleteReplyAfter(interaction, VIEW_EXPIRY_MS);
      } else if (action === 'leaderboard') {
        await leaderboard(interaction);
        deleteReplyAfter(interaction, VIEW_EXPIRY_MS);
      }
      return;
    }
    if (!interaction.isChatInputCommand()) return;
    if (!interaction.inGuild()) return void await interaction.reply({ content: 'This bot is available only in the employee server.', ephemeral: true });
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    if (interaction.commandName === 'trivia') await startTrivia(interaction);
    else if (interaction.commandName === 'quiz') await startQuiz(interaction);
    else if (interaction.commandName === 'leaderboard') {
      await leaderboard(interaction);
      deleteReplyAfter(interaction, VIEW_EXPIRY_MS);
    } else if (interaction.commandName === 'learn') {
      await learn(interaction, interaction.options.getString('topic') ?? undefined);
      deleteReplyAfter(interaction, VIEW_EXPIRY_MS);
    } else {
      await adminCommand(interaction);
      deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
    }
  } catch (error) {
    console.error('Interaction failed:', errorDetails(error));
    try {
      if (interaction.isRepliable() && interaction.deferred) {
        await interaction.editReply({ content: 'Something went wrong. Please try again or ask an administrator to check the bot log.' });
        deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
      } else if (interaction.isRepliable() && !interaction.replied) {
        await interaction.reply({ content: 'Something went wrong. Please try again or ask an administrator to check the bot log.', ephemeral: true });
        deleteReplyAfter(interaction, SHORT_EXPIRY_MS);
      }
    } catch (responseError) {
      // A network outage can prevent both the original acknowledgement and this fallback response.
      // Log that separately, but keep the bot running for its scheduled retries and later commands.
      console.error('Could not send the interaction error message:', errorDetails(responseError));
    }
  }
}

function dailyPostIsDue(): boolean {
  const [minuteText, hourText] = config.cron.split(' ');
  const now = new Intl.DateTimeFormat('en-US', { timeZone: config.timezone, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(new Date());
  const hour = Number(now.find(part => part.type === 'hour')?.value ?? 0);
  const minute = Number(now.find(part => part.type === 'minute')?.value ?? 0);
  return hour * 60 + minute >= Number(hourText) * 60 + Number(minuteText);
}

let maintenanceRunning = false;
async function runOperationalRecovery(reason: string): Promise<void> {
  if (maintenanceRunning) return;
  maintenanceRunning = true;
  try {
    await resetMissedStreaks();
    await disableExpiredDailyQuestions();
    await deleteExpiredDailyQuestions();
    if (dailyPostIsDue()) await ensureDailyQuestion(reason);
  } catch (error) {
    console.error(`Operational recovery failed (${reason}):`, errorDetails(error));
    await notifyBotInfo('operational-recovery-failed', '⚠️ Bot health check needs attention', `The bot could not complete its **${reason}** health check. It will try again automatically.\n\nError: ${String(errorDetails(error).message ?? 'Unknown error')}`);
  } finally {
    maintenanceRunning = false;
  }
}

function registerSchedules(): void {
  if (schedulesRegistered) return;
  schedulesRegistered = true;
  cron.schedule(config.cron, () => void ensureDailyQuestion('scheduled time').catch(error => console.error('Could not post daily question:', errorDetails(error))), { timezone: config.timezone });
  cron.schedule('5,20,35,50 * * * *', () => void runOperationalRecovery('periodic catch-up'), { timezone: config.timezone });
  cron.schedule('0 0 * * *', () => void runOperationalRecovery('midnight cleanup'), { timezone: config.timezone });
  cron.schedule('5 0 * * *', () => void runOperationalRecovery('midnight deletion'), { timezone: config.timezone });
  const heartbeat = setInterval(() => updateHealth({ lastHeartbeat: new Date().toISOString(), state: client.isReady() ? 'online' : 'reconnecting' }), 5 * 60 * 1000);
  heartbeat.unref();
}

client.once(Events.ClientReady, readyClient => {
  console.log(`Logged in as ${readyClient.user.tag}.`);
  updateHealth({ state: 'online', lastHeartbeat: new Date().toISOString(), lastDiscordConnection: new Date().toISOString() });
  registerSchedules();
  void notifyBotInfo('bot-online', wasUnhealthyAtStartup ? '⚠️ Bot reconnected after an interruption' : '✅ Pet First Aid Bot is online', wasUnhealthyAtStartup ? 'The health record indicates that the bot may have been offline or unreachable for more than 10 minutes. It is online now and is checking for missed work.' : 'The bot is connected and completing its startup health check.', wasUnhealthyAtStartup ? 0xd69e2e : 0x237804);
  void runOperationalRecovery('startup catch-up');
});

client.on(Events.ShardDisconnect, () => {
  updateHealth({ state: 'reconnecting', lastHeartbeat: new Date().toISOString(), lastError: 'Discord gateway disconnected; Discord.js is reconnecting.' });
  void notifyBotInfo('discord-disconnected', '⚠️ Bot temporarily disconnected from Discord', 'Discord.js is attempting to reconnect automatically.');
});
client.on(Events.ShardResume, () => {
  updateHealth({ state: 'online', lastHeartbeat: new Date().toISOString(), lastDiscordConnection: new Date().toISOString() });
  console.log('Bot reconnected to Discord.');
});
client.on(Events.Error, error => {
  console.error('Discord client error:', errorDetails(error));
  updateHealth({ state: 'reconnecting', lastError: String(errorDetails(error).message ?? 'Discord client error') });
});
client.on('interactionCreate', interaction => void handleInteraction(interaction));

async function startBot(): Promise<void> {
  let delay = 15_000;
  while (!client.isReady()) {
    try {
      await client.login(config.discordToken);
      return;
    } catch (error) {
      console.error('Could not connect to Discord at startup:', errorDetails(error));
      updateHealth({ state: 'reconnecting', lastHeartbeat: new Date().toISOString(), lastError: String(errorDetails(error).message ?? 'Discord connection failed') });
      console.warn(`Startup connection will retry in ${Math.ceil(delay / 1_000)} seconds.`);
      await wait(delay);
      delay = Math.min(delay * 2, 5 * 60 * 1000);
    }
  }
}

void startBot();
