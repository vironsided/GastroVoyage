# QA Smoke Matrix (MVP)

## Mobile + API Core Flow

- [x] Build passes static checks (`flutter analyze`).
- [x] Backend modules compile (`python -m compileall app`).
- [ ] Android emulator launch (manual run).
- [ ] Map screen loads without runtime type-cast crash.
- [ ] Dish detail opens and displays restaurant list.
- [ ] Profile tab loads tastings list.
- [ ] Admin moderation screen loads pending photos.

## API Sanity Checks

- [ ] `GET /health` returns `status=ok`.
- [ ] `GET /map/pins` returns frozen contract fields.
- [ ] `GET /dishes` returns list with stable schema.
- [ ] `GET /tastings?user_id=...` returns list without null cast issues.
- [ ] `PATCH /admin/photos/{id}` updates moderation status.

## Known Risks

- Android SDK/Gradle/JDK local mismatch can still block emulator startup.
- Google map rendering depends on emulator + plugin runtime compatibility.
