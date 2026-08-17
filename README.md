# Pet Pampering Plus — Pet First Aid Bot

An internal Discord training bot for first-aid trivia, training cards, daily questions, points, and employee streaks.

## First-time setup

1. In the Discord Developer Portal, install the bot into the employee server with the `bot` and `applications.commands` scopes. Give it permission to view and send messages in `#pet-first-aid`.
2. Install [Node.js 22 or newer](https://nodejs.org/).
3. In Supabase, open **SQL Editor**, create a new query, paste the complete contents of [`supabase/schema.sql`](supabase/schema.sql), and run it.
4. Copy `.env.example` to a new file named `.env`. Fill in `DISCORD_TOKEN` and `SUPABASE_SECRET_KEY`; keep this file private.
5. Install the project packages: `npm install`.
6. Register the slash commands in the test server: `npm run deploy:commands`.
7. Start the bot: `npm run dev`.

On Windows, you can instead double-click `setup-and-start.bat` the first time. After that, double-click `start-bot.bat` whenever you want the bot online.

Leave the terminal open while the bot is meant to run. The daily question posts at 6:00 AM Central Time and expires at midnight. If the computer is off then, it will not post until the bot is running again.

## Commands

- Everyone: `/trivia`, `/quiz`, `/leaderboard`, `/learn`
- Administrators: `/addquestion`, `/editquestion`, `/disablequestion`, `/trainingreport`, `/postdaily`, `/employee_stats`, `/reset_scores`

Correct answers earn 10 points. Daily streaks increase for each correct daily answer and reset after an incorrect or missed daily question. If the 6:00 AM daily post encounters a temporary network failure, the bot retries it and checks every 15 minutes through 11:45 AM Central until it succeeds.

Private bot responses clean themselves up automatically: unanswered trivia and quiz questions after 10 minutes; answer results and administrator confirmations after 1 minute; and learning cards, leaderboards, and reports after 5 minutes. The daily question remains public until its scheduled midnight removal.

Questions may have 2 choices (for True/False), 4 choices, or 5 choices. In the Supabase Table Editor, set `correct_option` using zero-based numbering: `0` is A, `1` is B, through `4` for E. Before adding True/False or five-choice questions to an existing database, run [`supabase/allow-variable-choice-counts.sql`](supabase/allow-variable-choice-counts.sql) once in Supabase SQL Editor.

## Content status

The database script includes three non-pet placeholder questions and two placeholder training cards, exactly for initial setup testing. `/quiz` becomes available when at least ten approved active questions have been added.
