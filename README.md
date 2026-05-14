# GastroVoyage

> Interactive World Cuisine Challenge — a gamified "Food Passport" mobile app where couples and friends taste their way through every country's cuisine.

This is the GastroVoyage monorepo: an Expo mobile app, a Next.js admin panel, and shared packages, all backed by Supabase.

## What's here

```
gastrovoyage/
  apps/
    mobile/      Expo + React Native (the user-facing passport app)
    admin/       Next.js 14 admin panel (manage restaurants, view analytics)
  packages/
    shared/      Shared types, theme tokens, Supabase clients, country data
  supabase/      Database migrations, seed data, local config
  docs/          Architecture, schema, setup guides
```

## Prerequisites

- Node.js **20+** (`.nvmrc` provided)
- pnpm **9+** (`npm install -g pnpm@9`)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (`npm install -g supabase`)
- **Dev client required** (NOT plain Expo Go). The map screen uses `@shopify/react-native-skia` which needs a custom native build:
  - Easy path: run `npx expo prebuild` then `npx expo run:ios` / `run:android` once.
  - Or use [EAS Build](https://docs.expo.dev/build/setup/) to produce a dev client.

## Quick start

```bash
pnpm install

# Copy env templates and fill in (see docs/setup-supabase.md)
cp apps/mobile/.env.example apps/mobile/.env.local
cp apps/admin/.env.example apps/admin/.env.local

# Link to remote Supabase (one-time)
pnpm supabase:link        # uses project ref hhdcohovxegvildfetvy

# Apply migrations to the linked project
pnpm db:push

# Generate TypeScript types from the live schema
pnpm db:types

# Run
pnpm dev:mobile           # Expo Dev Tools
pnpm dev:admin            # http://localhost:3000
```

## Project status

- Phase 1 — monorepo, schema, project scaffolds, auth wiring. **DONE**
- Phase 4 — Skia world map (vintage Natural Earth projection, pinch/pan/zoom, country modal, Instax stamps for visited countries). **DONE**
- Phase 2/3 (auth polish, country catalog admin), Phase 5 (camera), Phase 6 (restaurants + check-ins), Phase 7 (PDF export) — pending.

See [`docs/phase_roadmap.md`](docs/phase_roadmap.md) for full status.

## Documentation

- [`docs/system_architecture.md`](docs/system_architecture.md) — system design, module boundaries, data flow
- [`docs/database_schema.sql`](docs/database_schema.sql) — canonical schema (mirrors migrations)
- [`docs/setup-supabase.md`](docs/setup-supabase.md) — Supabase CLI walkthrough + key rotation
- [`docs/folder_structure.md`](docs/folder_structure.md) — where everything lives and why
- [`docs/phase_roadmap.md`](docs/phase_roadmap.md) — what ships in each phase

## Regenerating data

The world map shapes and country list are pre-baked into the `packages/shared` bundle.

```bash
# Regenerate the country master list (rare — sourced from `world-countries`)
pnpm data:countries

# Regenerate the pre-projected world atlas (after changing the projection
# or upgrading world-atlas). Writes packages/shared/src/data/world-shapes.json.
pnpm data:shapes
```

## Theme

"Modern Vintage" — deep navy, parchment cream, leather textures. Playfair Display for headings, Inter for UI. The mobile app should feel like a premium bespoke indie title, not a corporate CRUD app.

## License

Proprietary — all rights reserved.
