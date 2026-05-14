# Supabase Setup

This project is wired to the Supabase project at:

- **URL:** `https://hhdcohovxegvildfetvy.supabase.co`
- **Project ref:** `hhdcohovxegvildfetvy`

> ## SECURITY: rotate your secret key
>
> The Supabase **secret key** was shared during the planning conversation.
> Before you ship anything, rotate it:
>
> 1. Go to Supabase Dashboard → Project Settings → API Keys.
> 2. Click **Roll** next to the `secret` (service-role) key.
> 3. Update `SUPABASE_SERVICE_ROLE_KEY` in `apps/admin/.env.local` (and anywhere else it lives).
>
> The **publishable** (anon) key is safe to share — it's protected by Row-Level Security.

## 1. Install the Supabase CLI

```bash
npm install -g supabase
supabase --version    # >= 1.200.0 recommended
```

## 2. Login & link this repo to the remote project

```bash
supabase login                                          # opens browser
supabase link --project-ref hhdcohovxegvildfetvy        # one-time per machine
```

The link is stored in `supabase/.temp/` and is gitignored.

## 3. Fill in your environment files

```bash
# Mobile
cp apps/mobile/.env.example apps/mobile/.env.local

# Admin
cp apps/admin/.env.example apps/admin/.env.local
```

Both files need the project URL and **publishable** key. The admin file additionally needs the **secret** (service-role) key. Get them from the dashboard or use these (publishable only — rotate the secret first):

```env
# apps/mobile/.env.local
EXPO_PUBLIC_SUPABASE_URL=https://hhdcohovxegvildfetvy.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_KzxulcfTpMXotAR79Wc8UQ_eGIKDGiQ
```

```env
# apps/admin/.env.local
NEXT_PUBLIC_SUPABASE_URL=https://hhdcohovxegvildfetvy.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_KzxulcfTpMXotAR79Wc8UQ_eGIKDGiQ
SUPABASE_SERVICE_ROLE_KEY=<rotate-and-paste-new-secret-here>
```

Never commit `.env.local` — it's already in `.gitignore`.

## 4. Apply migrations to the remote project

The migrations live in `supabase/migrations/` and define the entire schema, RLS, and seed data.

```bash
pnpm db:push          # equivalent to `supabase db push`
```

The first run will prompt for the database password (the one with `[YOUR-PASSWORD]` in your direct connection string). The CLI will then run all four migrations in order:

1. `20260514000000_init_schema.sql` — tables, indexes, storage buckets
2. `20260514000100_rls_policies.sql` — RLS policies for every table
3. `20260514000200_seed_countries.sql` — 195 ISO countries
4. `20260514000300_seed_dev_users.sql` — Vusal & Sakina + sample visits

## 5. Generate TypeScript types

After the schema is applied, regenerate the typed client:

```bash
pnpm db:types
```

This overwrites `packages/shared/src/supabase/types.generated.ts`. Re-run it after every migration.

## 6. (Optional) Local development with Docker

If you want a fully isolated local DB:

```bash
supabase start           # boots local Postgres + Studio on :54323
supabase db reset        # applies migrations + seed locally
supabase stop
```

The mobile/admin apps would then point `*_SUPABASE_URL` at `http://127.0.0.1:54321`.

## 7. Make yourself an admin (Phase 2 task, manual for now)

The admin panel checks `auth.users.app_metadata.role = 'admin'`. After signing up via the admin UI (or mobile), promote your user:

```sql
-- Run in the SQL editor as the postgres user
update auth.users
set raw_app_meta_data = raw_app_meta_data || '{"role":"admin"}'::jsonb
where email = 'you@example.com';
```

A proper bootstrap script will land in Phase 2.

## Troubleshooting

| Symptom | Fix |
|-|-|
| `supabase link` fails with "not found" | Confirm project ref `hhdcohovxegvildfetvy` and that you're logged in (`supabase projects list`). |
| `db push` complains about migrations already applied | The remote DB and local migration history are out of sync; run `supabase db pull` then resolve before pushing. |
| `gen types` produces an empty file | You're not linked, or your auth token expired. Re-run `supabase login`. |
| RLS denies your admin queries | You haven't set `app_metadata.role = 'admin'` on your user yet. See step 7. |
