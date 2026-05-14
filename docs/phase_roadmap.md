# Phase Roadmap

## Phase 1 — Foundation (THIS DELIVERY)

Goal: a buildable, typecheck-clean skeleton that proves the architecture works end-to-end without the marquee features.

- [x] Monorepo (pnpm workspaces) with `apps/mobile`, `apps/admin`, `packages/shared`
- [x] Shared ESLint, Prettier, TypeScript base config
- [x] `docs/` with architecture, schema, setup, roadmap
- [x] Supabase: `init_schema`, `rls_policies`, `seed_countries`, `seed_dev_users` migrations
- [x] Storage buckets: `instax-photos`, `restaurant-images`, `map-exports`
- [x] Mobile: Expo SDK 52 + TS strict + NativeWind + Reanimated v3 + expo-router + providers
- [x] Mobile: auth screens (sign-in/sign-up) wired to Supabase, placeholder (tabs) screens
- [x] Admin: Next.js 14 App Router + Tailwind + `@supabase/ssr` + middleware gate + placeholder pages
- [x] Shared: theme tokens, domain types, 195-country JSON, Supabase client factories

**Out of scope:** any of the actual feature UIs.

## Phase 2 — Auth polish & profile

- Real-looking sign-in screen (vintage parchment login card)
- Profile editing (display name, avatar via `restaurant-images` bucket pattern)
- Password reset email flow
- Admin role bootstrap script (sets `app_metadata.role = 'admin'`)

## Phase 3 — Country & cuisine catalog

- Country detail screen (read-only): flag, signature dishes, fun facts
- Admin: countries CRUD form
- Admin: cuisines CRUD with image upload

## Phase 4 — The Skia map (DONE)

- [x] Custom vintage paper map canvas (`@shopify/react-native-skia`)
- [x] 192 countries rendered from world-atlas 50m, pre-projected with d3-geo `geoNaturalEarth1` (Tuvalu and Vatican City are too small to appear in the topology — known gap)
- [x] Pinch-to-zoom, pan, double-tap zoom (gesture-handler + reanimated worklets)
- [x] Tap to open a country bottom-sheet modal (visited vs unvisited state)
- [x] Empty-state dots for unvisited countries; tilted Instax stamps with flag emoji for visited ones
- [x] Staggered region-by-region first-paint animation
- [x] Light haptic on country tap
- [x] Compass rose decoration in the corner
- [x] Dev-only "Mark visited" action so the visit/photo-placement state can be exercised without waiting for Phase 5
- [ ] Sound cue on country selection — deferred to Phase 7 polish pass

## Phase 5 — Instax camera & visit logging

- Custom camera screen (`expo-camera`) with overlay Instax frame
- Post-capture: notes, 5-star rating, date picker
- Photo upload to `instax-photos` (signed POST, retries)
- `visits` upsert (unique per user_id + country_id)
- Map update: 3D flip + paper-placement animation when a country is filled
- Progress bar + region badges

## Phase 6 — Restaurants & monetization

- Admin: full restaurants CRUD with partner toggle and commission rate
- Mobile: "Where to try in your city?" inside country modal
- Geofenced check-in (GPS distance to restaurant)
- `check_ins` write with anti-fraud distance gate
- Admin: analytics page (check-ins by partner, month-over-month)

## Phase 7 — PDF poster generation

- Node worker service (separate `apps/pdf-service` or Supabase Edge Function with rendering offloaded)
- Compose 300dpi A2 master map + user photos
- Write to `map-exports`, return signed URL
- Mobile: unlock UI at 100% (or per region) with shimmer + Lottie celebration

## Phase 8 — AI recommendations (decoupled)

- `pgvector` extension on Supabase
- Embeddings for restaurants and cuisine descriptions
- Local AI server reads change feed, writes recommendation scores back
- Mobile fetches via `/recommendations` Edge Function — implementation behind the endpoint can swap freely
