# Pet Pampering Plus — Pet First Aid Bot

An internal Discord training bot for first-aid trivia, training cards, daily questions, points, and employee streaks.

## First-time setup

1. In the Discord Developer Portal, install the bot into the employee server with the `bot` and `applications.commands` scopes. Give it permission to view and send messages in `#pet-first-aid` and `#daily-first-aid`.
2. Install [Node.js 22 or newer](https://nodejs.org/).
3. In Supabase, open **SQL Editor**, create a new query, paste the complete contents of [`supabase/schema.sql`](supabase/schema.sql), and run it.
4. Copy `.env.example` to a new file named `.env`. Fill in `DISCORD_TOKEN`, `SUPABASE_SECRET_KEY`, and the channel ID for the private `#bot-info` channel as `BOT_INFO_CHANNEL_ID`; keep this file private. The bot needs View Channel, Send Messages, Embed Links, Read Message History, and Manage Messages in `#daily-first-aid`, plus View Channel, Send Messages, and Embed Links in `#bot-info`.
5. Install the project packages: `npm install`.
6. Register the slash commands in the test server: `npm run deploy:commands`.
7. Start the bot: `npm run dev`.

On Windows, you can instead double-click `setup-and-start.bat` the first time. After that, double-click `start-bot.bat` whenever you want the bot online.

Leave the terminal open while the bot is meant to run. The daily question posts at 6:00 AM Central Time and expires at midnight. If the computer is off then, it will not post until the bot is running again.

## Commands

- Everyone: `/trivia`, `/quiz`, `/leaderboard`, `/learn`
- Administrators: `/addquestion`, `/editquestion`, `/disablequestion`, `/trainingreport`, `/postdaily`, `/testquestion`, `/employee_stats`, `/reset_scores`

A correct daily answer earns 10 points. Correct practice answers from Trivia and Quiz earn 1 point each. Daily streaks increase for each correct daily answer and reset after an incorrect or missed daily question. Daily questions rotate through every enabled question before beginning a new rotation. The private leaderboard includes all-time and current-month standings, your daily-trivia status, and progress toward learning milestones (every 25 correct answers and every 7 streak days). If the 6:00 AM daily post encounters a temporary network failure, the bot retries it and checks every 15 minutes through 11:45 AM Central until it succeeds.

Private bot responses clean themselves up automatically: unanswered trivia and quiz questions after 10 minutes; answer results and administrator confirmations after 1 minute; and learning cards, leaderboards, and reports after 5 minutes. The daily question remains public until its scheduled midnight removal.

## Reliability and health information

The bot automatically retries short-lived Discord and Supabase failures. It checks for missed streak resets, expired daily questions, and a missing daily question when it starts and every 15 minutes while online. A daily question that was not deleted is retried and removed during the next health check.

The `logs` folder is created automatically beside this README. It contains:

- `pet-first-aid-bot.log` — timestamped operating and error messages.
- `bot-health.html` — a simple local status page. Open it in a browser and refresh it to see the latest connection, database, daily-post, and cleanup status. If its last heartbeat is more than 10 minutes old, the bot may be offline.
- `bot-health.json` — the same status data in a technical format.

The bot posts recovery and attention notices in the private `#bot-info` channel. It cannot send a notice while the computer itself is offline, but on the next successful startup it detects a stale health record and reports that it may have been unavailable.

Existing databases must also run [`supabase/add-reliability.sql`](supabase/add-reliability.sql) once in Supabase SQL Editor before starting this version. This safely makes answer recording, points, and streaks one database operation.

Questions may have 2 choices (for True/False), 4 choices, or 5 choices. In the Supabase Table Editor, set `correct_option` using zero-based numbering: `0` is A, `1` is B, through `4` for E. Before adding True/False or five-choice questions to an existing database, run [`supabase/allow-variable-choice-counts.sql`](supabase/allow-variable-choice-counts.sql) once in Supabase SQL Editor.

Questions can optionally show an image. Put the image in `assets/questions`, then set its filename in the `image_filename` database column or the optional `image` field of `/addquestion`. Use `/testquestion` with a question ID to privately test a question without awarding points or changing scores, streaks, or training reports.

## Content status

The database script includes three non-pet placeholder questions and two placeholder training cards, exactly for initial setup testing. `/quiz` becomes available when at least five approved active questions have been added.
