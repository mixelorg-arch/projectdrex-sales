# 5pm daily report — setup

The ledger currently lives in your browser, which is why nothing can email it
while the page is closed. These steps move the data to Supabase and add a
scheduled job that builds a PDF at **17:00 Manila** and sends it to
`projectdrexxx@gmail.com`.

You need to do steps 1–4 yourself (they involve creating accounts and pasting
secrets). Everything after that is code that is already written.

---

## 1. Create the Supabase project

1. Sign up at <https://supabase.com> and create a project. Pick the Singapore
   region — it is the closest to you.
2. Once it finishes building, go to **Project Settings → API** and copy:
   * **Project URL** — looks like `https://abcdefgh.supabase.co`
   * **anon public** key — safe to put in the web page; row level security is
     what actually protects the data.

Do **not** copy the `service_role` key into anything public. It only ever goes
into Edge Function secrets, in step 4.

## 2. Create the tables

Open **SQL Editor → New query**, paste the whole of [`schema.sql`](schema.sql),
and run it. It creates three tables and turns on row level security so each row
is readable only by the account that owns it.

## 3. Switch on the sync in the app

Open [`config.js`](../config.js) and paste in the two values from step 1:

```js
window.LEDGER_CONFIG = {
  supabaseUrl: 'https://abcdefgh.supabase.co',
  supabaseAnonKey: 'eyJhbGci...'
};
```

Commit and push, and the ledger grows a **Sign in** control. Sign in with your
email — you get a link, no password. **The first person to sign in becomes the
owner automatically**; everyone after that has no access until you add them (the
snippet for that is at the bottom of `schema.sql`).

In Supabase, go to **Authentication → URL Configuration** and add
`https://mixelorg-arch.github.io/projectdrex-sales/` to **Redirect URLs**, or the
sign-in link will bounce.

Leaving `config.js` blank keeps everything exactly as it is now: local to one
browser, nothing sent anywhere.

## 4. Create the Resend account and set the secrets

1. Sign up at <https://resend.com>.
2. Verify a sender. Either add a domain you own, or use Resend's onboarding
   sender for testing. Gmail will accept either.
3. Copy the API key.
4. In Supabase, go to **Edge Functions → Secrets** and add:

   | Name | Value |
   |---|---|
   | `RESEND_API_KEY` | the key from Resend |
   | `REPORT_FROM` | `Ledger <ledger@yourdomain.com>` — must be the verified sender |
   | `REPORT_TO` | `projectdrexxx@gmail.com` |
   | `CRON_SECRET` | any long random string you invent |

   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically —
   do not add them.

## 5. Deploy the function

With the Supabase CLI (`brew install supabase/tap/supabase`):

```
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy daily-report --no-verify-jwt
```

`--no-verify-jwt` is deliberate: the function is protected by `CRON_SECRET`
instead, and refuses to run at all if that secret is missing or wrong.

## 6. Schedule it for 5pm Manila

Back in the SQL editor. The Philippines does not observe daylight saving, so
17:00 Manila is 09:00 UTC every day of the year.

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'ledger-daily-report',
  '0 9 * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT-REF>.supabase.co/functions/v1/daily-report?scope=day',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'x-cron-secret', '<YOUR CRON_SECRET>'
               )
  );
  $$
);
```

To check what is scheduled: `select * from cron.job;`
To remove it: `select cron.unschedule('ledger-daily-report');`

## 7. Test it before trusting it

Send one immediately, without waiting for 5pm:

```
curl -X POST "https://<PROJECT-REF>.supabase.co/functions/v1/daily-report?scope=day&date=2026-08-05" \
  -H "x-cron-secret: <YOUR CRON_SECRET>"
```

A `200` and a PDF in the inbox means it works. The same endpoint takes
`scope=week` and `scope=month`, so a weekly or monthly email is just a second
`cron.schedule` line.

---

## How the sync behaves

* Every change is written to this browser **first**, then pushed. If the network
  is down the edit is queued and goes up on the next successful sync — nothing
  is lost and nothing is blocked.
* Conflicts resolve per row, newest wins, using the database's clock rather than
  the device's. Two people editing different days never collide.
* Deletes are kept as tombstones so they propagate instead of being resurrected
  by a device with a stale copy.
* If Supabase is unreachable, or `config.js` is blank, the ledger simply works
  the way it does today.
