# Folder Structure

```
gastrovoyage/
├─ package.json                         # workspace root
├─ pnpm-workspace.yaml
├─ .npmrc                               # node-linker=hoisted for Expo
├─ tsconfig.base.json                   # shared compiler options
├─ .eslintrc.cjs                        # shared ESLint base
├─ .prettierrc.js
├─ .gitignore
├─ .nvmrc                               # Node 20
├─ README.md
│
├─ docs/
│  ├─ system_architecture.md
│  ├─ database_schema.sql               # canonical DDL (mirrors migrations)
│  ├─ setup-supabase.md                 # CLI walkthrough + key rotation
│  ├─ folder_structure.md               # this file
│  └─ phase_roadmap.md
│
├─ supabase/
│  ├─ config.toml                       # local dev settings
│  ├─ seed.sql                          # local db reset seed
│  └─ migrations/
│     ├─ 20260514000000_init_schema.sql
│     ├─ 20260514000100_rls_policies.sql
│     ├─ 20260514000200_seed_countries.sql
│     └─ 20260514000300_seed_dev_users.sql
│
├─ packages/
│  └─ shared/                           # @gastrovoyage/shared
│     ├─ package.json
│     ├─ tsconfig.json
│     ├─ index.ts                       # public barrel
│     └─ src/
│        ├─ supabase/
│        │  ├─ client.ts                # createClient factory
│        │  ├─ admin.ts                 # service-role factory (server guard)
│        │  └─ types.generated.ts       # `supabase gen types typescript`
│        ├─ domain/
│        │  ├─ country.ts
│        │  ├─ cuisine.ts
│        │  ├─ restaurant.ts
│        │  ├─ visit.ts
│        │  ├─ badge.ts
│        │  └─ user.ts
│        ├─ data/
│        │  ├─ countries.json           # 195 ISO countries + region + centroid
│        │  └─ world-shapes.json        # pre-projected Skia paths for the Phase 4 map
│        └─ constants/
│           ├─ theme.ts                 # palette, fonts, spacing tokens
│           └─ regions.ts               # region groupings + badge mapping
│
└─ apps/
   ├─ mobile/                           # @gastrovoyage/mobile  (Expo SDK 52)
   │  ├─ package.json
   │  ├─ app.config.ts
   │  ├─ babel.config.js
   │  ├─ metro.config.js
   │  ├─ tailwind.config.js
   │  ├─ global.css
   │  ├─ tsconfig.json
   │  ├─ .env.example
   │  ├─ assets/                        # icon, splash, fonts (Phase 4+)
   │  └─ src/
   │     ├─ app/                        # expo-router file-based routes
   │     │  ├─ _layout.tsx              # Providers + auth gate
   │     │  ├─ (auth)/
   │     │  │  ├─ _layout.tsx
   │     │  │  ├─ sign-in.tsx
   │     │  │  └─ sign-up.tsx
   │     │  ├─ (tabs)/
   │     │  │  ├─ _layout.tsx
   │     │  │  ├─ index.tsx             # Map screen (placeholder Phase 1)
   │     │  │  ├─ passport.tsx          # Progress + badges
   │     │  │  └─ profile.tsx
   │     │  └─ +not-found.tsx
   │     ├─ providers/
   │     │  ├─ AuthProvider.tsx
   │     │  ├─ QueryProvider.tsx
   │     │  └─ ThemeProvider.tsx
   │     ├─ lib/
   │     │  ├─ supabase.ts              # wraps shared client + AsyncStorage
   │     │  └─ haptics.ts
   │     ├─ components/
   │     │  └─ ui/
   │     │     ├─ Button.tsx
   │     │     ├─ Card.tsx
   │     │     └─ Shimmer.tsx
   │     ├─ features/
   │     │  └─ map/                       # Phase 4 — Skia world map
   │     │     ├─ WorldMap.tsx            # entry + HUD + modal wiring
   │     │     ├─ MapCanvas.tsx           # Skia <Canvas> with all painted layers
   │     │     ├─ hooks/
   │     │     │  ├─ useMapData.ts        # world atlas + user visits
   │     │     │  ├─ useMapGestures.ts    # pinch/pan/double-tap
   │     │     │  └─ useCountryHitTest.ts # tap -> iso_a3
   │     │     ├─ layers/
   │     │     │  ├─ PaperBackground.tsx
   │     │     │  ├─ CountryShapes.tsx    # filled regions w/ staggered fade-in
   │     │     │  ├─ CountryBorders.tsx
   │     │     │  ├─ CompassRose.tsx
   │     │     │  └─ StampsOverlay.tsx    # RN-view overlay (dots + Instax)
   │     │     ├─ modal/
   │     │     │  └─ CountryModal.tsx
   │     │     └─ utils/
   │     │        ├─ projection.ts        # screen<->atlas math
   │     │        └─ hitTest.ts           # bbox + centroid fallback
   │     ├─ hooks/
   │     │  └─ useAuth.ts
   │     └─ types/
   │        └─ env.d.ts
   │
   └─ admin/                            # @gastrovoyage/admin  (Next.js 14)
      ├─ package.json
      ├─ next.config.mjs
      ├─ tailwind.config.ts
      ├─ postcss.config.js
      ├─ tsconfig.json
      ├─ .env.example
      └─ src/
         ├─ app/
         │  ├─ layout.tsx
         │  ├─ page.tsx                 # redirects based on auth
         │  ├─ globals.css
         │  ├─ login/
         │  │  └─ page.tsx
         │  └─ (dashboard)/
         │     ├─ layout.tsx            # sidebar shell
         │     ├─ dashboard/page.tsx
         │     ├─ countries/page.tsx
         │     ├─ restaurants/page.tsx
         │     └─ analytics/page.tsx
         ├─ components/
         │  └─ ui/                      # primitives
         ├─ lib/
         │  └─ supabase/
         │     ├─ server.ts             # cookie-based RSC client
         │     ├─ admin.ts              # service-role (server-only)
         │     └─ middleware.ts         # auth refresh helper
         └─ middleware.ts               # gate for /(dashboard)/*
```

## Naming conventions

- **Files:** `kebab-case.ts` for utilities, `PascalCase.tsx` for React components, `_layout.tsx`/`(group)` for expo-router.
- **DB tables:** snake_case, plural (`visits`, `check_ins`).
- **TS types:** PascalCase, never `I`-prefixed (`Visit`, not `IVisit`).
- **Env vars:**
  - Mobile (client-readable): `EXPO_PUBLIC_*`
  - Admin (client-readable): `NEXT_PUBLIC_*`
  - Server-only: bare (`SUPABASE_SERVICE_ROLE_KEY`)
