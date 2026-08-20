import { SlashCommandBuilder } from 'discord.js';

export const commands = [
  new SlashCommandBuilder().setName('trivia').setDescription('Answer one random trivia question.'),
  new SlashCommandBuilder().setName('quiz').setDescription('Start a five-question quiz.'),
  new SlashCommandBuilder().setName('leaderboard').setDescription('Show the current leaderboard.'),
  new SlashCommandBuilder().setName('learn').setDescription('Show a random training card.').addStringOption(option => option.setName('topic').setDescription('Optional topic to filter by.')),
  new SlashCommandBuilder()
    .setName('addquestion').setDescription('Add a 2-, 4-, or 5-choice question.')
    .addStringOption(option => option.setName('prompt').setDescription('The question.').setRequired(true))
    .addStringOption(option => option.setName('a').setDescription('Answer A.').setRequired(true))
    .addStringOption(option => option.setName('b').setDescription('Answer B.').setRequired(true))
    .addIntegerOption(option => option.setName('correct').setDescription('Correct answer number: 1=A through 5=E.').setRequired(true).setMinValue(1).setMaxValue(5))
    .addStringOption(option => option.setName('why').setDescription('Optional explanation of why the answer is correct.'))
    .addStringOption(option => option.setName('c').setDescription('Answer C (required for 4 or 5 choices).'))
    .addStringOption(option => option.setName('d').setDescription('Answer D (required for 4 or 5 choices).'))
    .addStringOption(option => option.setName('e').setDescription('Answer E (optional fifth choice).'))
    .addStringOption(option => option.setName('topic').setDescription('Optional topic.')),
  new SlashCommandBuilder()
    .setName('editquestion').setDescription('Edit a question prompt or explanation.')
    .addStringOption(option => option.setName('id').setDescription('Question ID.').setRequired(true))
    .addStringOption(option => option.setName('prompt').setDescription('Replacement question text.'))
    .addStringOption(option => option.setName('why').setDescription('Replacement explanation.'))
    .addStringOption(option => option.setName('topic').setDescription('Replacement topic.')),
  new SlashCommandBuilder().setName('disablequestion').setDescription('Disable a question.').addStringOption(option => option.setName('id').setDescription('Question ID.').setRequired(true)),
  new SlashCommandBuilder().setName('trainingreport').setDescription('Show training activity for this server.'),
  new SlashCommandBuilder().setName('postdaily').setDescription('Post today\'s daily question now.'),
  new SlashCommandBuilder().setName('postmenu').setDescription('Post the employee button menu in this channel.'),
  new SlashCommandBuilder().setName('employee_stats').setDescription('Show points and streaks.').addUserOption(option => option.setName('employee').setDescription('Optional employee.')),
  new SlashCommandBuilder().setName('reset_scores').setDescription('Reset every employee score and streak.').addStringOption(option => option.setName('confirm').setDescription('Type RESET to confirm.').setRequired(true))
].map(command => command.toJSON());
