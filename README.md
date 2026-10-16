# The Retreat

A live polling and game app for the WASH Coordination Team Retreat (22–23 October 2026): votes, word clouds, ratings, a timed quiz with a leaderboard, team scores, a QR treasure hunt, and a test site check for informal settlements.

It is a plain static site (no build step) on Vercel, with Supabase as the live database.

## Pages

| Address | Who | What |
| --- | --- | --- |
| `/` | Everyone, on their phone | Join with a name and team, then answer whatever is on the screen |
| `/screen` | The projector | Join QR code, live results, top players, team scores, hunt progress, podium. Double-click for full screen. |
| `/host` | The facilitator (passphrase) | Run the session, edit questions, give team points, manage the hunt, read site checks, reset |
| `/card?c=CODE` | Teams during the hunt | Opened by scanning a hunt card's QR code |
| `/assess` | Teams at the lake | Site check with photos (test version) |
| `/print` | The facilitator | Join poster plus all hunt cards with QR codes, ready to print on A4 |

## Setup (once)

1. **Supabase**: create a project, open **SQL Editor → New query**, paste `supabase/schema.sql`, run it. Then run `supabase/set-passphrase.sql` with your own host passphrase in place of the placeholder.
2. Copy the **Project URL** and **anon public key** from **Project Settings → API** into `public/config.js`.
3. **Vercel**: import this repository. No build settings are needed; `vercel.json` serves the `public` folder. Add the domain under **Settings → Domains**.

## Scoring

- **Quiz (individual):** a correct answer scores 500 to 1000 points; the faster, the more. Wrong or missing answers score 0.
- **Team score:** points given by the host + hunt card points + 1 point for every correct quiz answer by a team member.
- **Hunt:** each card gives points once per team, and a team has 3 tries per card. Letter cards reveal one letter of the secret word.

## Changing the site check

The questions live in `public/form.js`. Each option has a `risk` value from 0 to 3; the total sets the severity level.

## Security notes

- Nobody can write to the database directly. Every change goes through database functions that check the player's token or the host passphrase.
- Quiz answers, hunt answers, the secret word, hunt submissions and site checks cannot be read by players.
- Photos go to a public storage bucket under random file names. Do not photograph people's faces during the test.
