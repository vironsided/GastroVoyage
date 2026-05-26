# GastroVoyage Backend

FastAPI service for Baku-first MVP.

## Run

1. Create virtualenv and install deps:
   - `pip install -r requirements.txt`
2. Configure `.env` if needed:
   - `DATABASE_URL` equivalent is `database_url` in settings (`app/core/config.py`).
3. Seed sample data:
   - `python -m app.seed.baku_seed`
   - Optional photo sync from TasteAtlas pages:
     - `python -m app.seed.tasteatlas_images_sync`
4. Start API:
   - `uvicorn app.main:app --reload`

## Main Endpoints

- `GET /health`
- `GET /map/pins`
- `GET /dishes` (supports `q`, `cuisine`, `country`)
- `GET /dishes/{dish_id}`
- `GET /dishes/{dish_id}/restaurants`
- `POST /tastings`
- `GET /tastings?user_id=...`
- `GET /admin/summary`
- `GET/POST/PUT/DELETE /admin/dishes`
- `GET/POST/PUT/DELETE /admin/restaurants`
- `GET/POST/PUT/DELETE /admin/restaurant-dishes`
- `GET /admin/photos/pending`
- `PATCH /admin/photos/{photo_id}`

## Contract Notes

- API contract for mobile integration is frozen in `../docs/API_CONTRACT.md`.
- Map endpoint intentionally returns both map coords (`lat`, `lng`) and dish-origin coords (`origin_lat`, `origin_lng`) for backward compatibility.
