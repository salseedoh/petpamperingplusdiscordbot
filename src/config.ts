import 'dotenv/config';

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const [hour, minute] = (process.env.DAILY_QUESTION_TIME ?? '06:00').split(':');

export const config = {
  discordToken: required('DISCORD_TOKEN'),
  applicationId: required('DISCORD_APPLICATION_ID'),
  guildId: required('DISCORD_GUILD_ID'),
  dailyChannelId: required('DAILY_CHANNEL_ID'),
  supabaseUrl: required('SUPABASE_URL'),
  supabaseSecretKey: required('SUPABASE_SECRET_KEY'),
  timezone: process.env.TIMEZONE ?? 'America/Chicago',
  cron: `${Number(minute)} ${Number(hour)} * * *`
};
