# Delivery Execution (Baku-first)

## Phase 0 - Foundation (done)

- Monorepo initialized with `mobile` and `backend`.
- Legal boundary documented in `docs/LEGAL_BOUNDARY.md`.
- Data model documented in `docs/DATA_MODEL.md`.
- ADR accepted: FastAPI + Flutter + Mapbox.

## Phase 1 - Core Baku Experience (done in skeleton form)

- Map pins API (`GET /map/pins`) implemented.
- Dish list and dish details APIs implemented.
- Dish-to-restaurants flow implemented (`GET /dishes/{dish_id}/restaurants`).
- Flutter map + search + dish list + detail screen implemented.

## Phase 2 - Progress + Proof (skeleton implemented)

- Tasting creation endpoint with optional proof photo implemented (`POST /tastings`).
- Instax-style status card component implemented in mobile UI.
- Challenge and profile screens added as MVP placeholders.

## Phase 3 - Admin + Monetization Readiness (skeleton implemented)

- Admin summary endpoint implemented (`GET /admin/summary`).
- Data structures support verification and confidence scoring.

## Next Immediate Steps

1. Add auth and user ownership checks.
2. Add moderation workflow endpoints.
3. Add map clustering and location-based filtering.
4. Build admin web panel UI over existing admin endpoints.
