# API Contract (v2.1.0)

All non-public endpoints require a Bearer JWT issued by `/auth/signin` or
`/auth/signup`. The user is identified by the validated token — there is no
`user_id` in query strings or request bodies anymore.

## Auth (public, no token)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/signup`   | `{email, password, display_name}` → `AuthResult` |
| `POST` | `/auth/signin`   | `{email, password}` → `AuthResult` |
| `POST` | `/auth/resend`   | `{email}` → `{ok: true}` |

`AuthResult` = `{user_id, email, display_name, home_city?, access_token, refresh_token, email_confirmed}`.

## Profile (Bearer required)

| Method | Path | Body |
|---|---|---|
| `GET`   | `/profile/me` | — |
| `PATCH` | `/profile/me` | `{display_name?, home_city?}` |

## Countries (Bearer required, except `/regions`)

| Method | Path | Query |
|---|---|---|
| `GET` | `/countries`           | `?region=&visited=` (both optional) |
| `GET` | `/countries/regions`   | (public) |
| `GET` | `/countries/{id}`      | — |

## Visits (Bearer required)

| Method | Path | Body |
|---|---|---|
| `GET`    | `/visits?limit=N` | — |
| `POST`   | `/visits`         | `{country_id, visited_on, notes?, rating?, photo_path?}` |
| `PATCH`  | `/visits/{id}`    | `{notes?, rating?, visited_on?, photo_path?}` |
| `DELETE` | `/visits/{id}`    | — |

## Badges (Bearer required)

| Method | Path |
|---|---|
| `GET` | `/badges` |

## Map (Bearer required)

| Method | Path |
|---|---|
| `GET` | `/map/countries` |

## Uploads (Bearer required)

| Method | Path | Notes |
|---|---|---|
| `POST` | `/uploads` | `multipart/form-data` with `file`. Max 8 MB. Allowed: `image/jpeg, image/png, image/webp, image/heic`. Returns `{url}`. Photos are stored under `<user_id>/<uuid>.<ext>`. |

## Errors

- `401 Unauthorized` — missing/invalid/expired token. Mobile client raises `UnauthorizedException`.
- `403 Forbidden` — token valid, but action not allowed (e.g. email not verified for sign-in).
- `404 Not Found` — resource not owned by the current user, or doesn't exist.
- `413 Payload Too Large` — upload > 8 MB.
- `415 Unsupported Media Type` — upload content-type not in allowlist.
- `422 Unprocessable Entity` — validation failure (email format, password length).

## Nullability rules (preserved)

- `id` fields: never null.
- Text fields consumed by UI: never null (empty string fallback).
- Geo fields: numeric.
- Optional: `image_url`, `moderation_status`, `photo_path`, `home_city`.

## CORS

`CORS_ORIGINS` env var, comma-separated. Default for dev:
`http://localhost:*,http://10.0.2.2:*,http://127.0.0.1:*`.

For production set explicitly, e.g.
`CORS_ORIGINS=https://gastrovoyage.app,https://staging.gastrovoyage.app`.

## Mobile client base URL

Set at build time:

```bash
flutter build apk --release --dart-define=API_URL=https://api.gastrovoyage.app
```

Default (no flag) = `http://10.0.2.2:8000` (Android emulator → host loopback).
