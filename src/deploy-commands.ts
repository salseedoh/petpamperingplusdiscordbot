import { REST, Routes } from 'discord.js';
import { commands } from './commands.js';
import { config } from './config.js';

const rest = new REST({ version: '10' }).setToken(config.discordToken);

const retryDelays = [0, 30_000, 60_000, 120_000];
let lastError: unknown;

for (const [attempt, delay] of retryDelays.entries()) {
  if (delay) {
    console.warn(`Discord command registration retrying in ${delay / 1_000} seconds...`);
    await new Promise(resolve => setTimeout(resolve, delay));
  }
  try {
    await rest.put(Routes.applicationGuildCommands(config.applicationId, config.guildId), { body: commands });
    console.log(`Registered ${commands.length} commands in test server ${config.guildId}.`);
    lastError = undefined;
    break;
  } catch (error) {
    lastError = error;
    console.warn(`Discord command registration failed (attempt ${attempt + 1}/${retryDelays.length}).`, error);
  }
}

if (lastError) throw lastError;
