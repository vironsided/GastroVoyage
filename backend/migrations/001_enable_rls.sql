-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Row Level Security baseline
-- Run this once in Supabase SQL editor (or via psql) after the schema exists.
--
-- After this migration:
--   • profiles, visits, user_badges are isolated per user_id = auth.uid()
--   • countries, badges remain world-readable (reference data)
--
-- The FastAPI service key bypasses RLS, but enabling RLS protects against:
--   • a leaked anon key (mobile / web direct connections)
--   • a misconfigured edge function
--   • future migration to direct Supabase client calls from mobile
-- ─────────────────────────────────────────────────────────────────────────────

-- ── profiles ─────────────────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ── visits ───────────────────────────────────────────────────────────────────
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visits_select_own" ON visits;
CREATE POLICY "visits_select_own" ON visits
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "visits_insert_own" ON visits;
CREATE POLICY "visits_insert_own" ON visits
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "visits_update_own" ON visits;
CREATE POLICY "visits_update_own" ON visits
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "visits_delete_own" ON visits;
CREATE POLICY "visits_delete_own" ON visits
  FOR DELETE USING (auth.uid() = user_id);

-- ── user_badges ──────────────────────────────────────────────────────────────
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_badges_select_own" ON user_badges;
CREATE POLICY "user_badges_select_own" ON user_badges
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_badges_insert_own" ON user_badges;
CREATE POLICY "user_badges_insert_own" ON user_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── countries (public read) ──────────────────────────────────────────────────
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "countries_public_read" ON countries;
CREATE POLICY "countries_public_read" ON countries
  FOR SELECT USING (true);

-- ── badges (public read) ─────────────────────────────────────────────────────
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "badges_public_read" ON badges;
CREATE POLICY "badges_public_read" ON badges
  FOR SELECT USING (true);

-- ── Storage policies for visit-photos bucket ─────────────────────────────────
-- Photos are uploaded under "<user_id>/<uuid>.<ext>" so we constrain access
-- based on the path prefix.

-- Allow anyone to read (the bucket is public so photos can be embedded in feeds).
DROP POLICY IF EXISTS "visit_photos_public_read" ON storage.objects;
CREATE POLICY "visit_photos_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'visit-photos');

-- Only the owner can write or delete their own folder.
DROP POLICY IF EXISTS "visit_photos_owner_write" ON storage.objects;
CREATE POLICY "visit_photos_owner_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'visit-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "visit_photos_owner_delete" ON storage.objects;
CREATE POLICY "visit_photos_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'visit-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
