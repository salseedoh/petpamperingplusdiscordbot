import { SlashCommandBuilder } from 'discord.js';

export const commands = [
  new SlashCommandBuilder().setName('trivia').setDescription('Answer one random trivia question.'),
  new SlashCommandBuilder().setName('quiz').setDescription('Start a ten-question quiz.'),
  new SlashCommandBuilder().setName('leaderboard').setDescription('Show the current leaderboard.'),
  new SlashCommandBuilder().setName('learn').setDescription('Show a random training card.').addStringOption(option => option.setName('topic').setDescription('Optional topic to filter by.')),
  new SlashCommandBuilder()
    .setName('addquestion').setDescription('Add a four-choice question.')
    .addStringOption(option => option.setName('prompt').setDescription('The question.').setRequired(true))
    .addStringOption(option => option.setName('a').setDescription('Answer A.').setRequired(true))
    .addStringOption(option => option.setName('b').setDescription('Answer B.').setRequired(true))
    .addStringOption(option => option.setName('c').setDescription('Answer C.').setRequired(true))
    .addStringOption(option => option.setName('d').setDescription('Answer D.').setRequired(true))
    .addIntegerOption(option => option.setName('correct').setDescription('Correct answer: 1=A, 2=B, 3=C, 4=D.').setRequired(true).setMinValue(1).setMaxValue(4))
    .addStringOption(option => option.setName('why').setDescription('Why the answer is correct.').setRequired(true))
    .addStringOption(option => option.setName('topic').setDescription('Optional topic.')),
  new SlashCommandBuilder()
    .setName('editquestion').setDescription('Edit a question prompt or explanation.')
    .addStringOption(option => option.setName('id').setDescription('Question ID.').setRequired(true))
    .addStringOption(option => option.setName('prompt').setDescription('Replacement question text.'))
    .addStringOption(option => option.setName('why').setDescription('Replacement explanation.'))
    .addStringOption(option => option.setName('topic').setDescription('Replacement topic.')),
  new SlashCommandBuilder().setName('disablequestion').setDescription('Disable a question.').addStringOption(option => option.setName('id').setDescription('Question ID.').setRequired(true)),
  new SlashCommandBuilder().setName('trainingreport').setDescription('Show training activity for this server.'),
  new SlashCommandBuilder().setName('employee_stats').setDescription('Show points and streaks.').addUserOption(option => option.setName('employee').setDescription('Optional employee.')),
  new SlashCommandBuilder().setName('reset_scores').setDescription('Reset every employee score and streak.').addStringOption(option => option.setName('confirm').setDescription('Type RESET to confirm.').setRequired(true))
].map(command => command.toJSON());
