-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Social network: follows, stories, passport visibility
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the social
-- feature will work.
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • follows   — directed follow graph with pending/accepted request status
--   • stories   — ephemeral photo posts shown in the social feed
--   • profiles  — gains a passport_visibility column (public/followers/private)
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── follows ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS follows (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id  uuid        NOT NULL,
  following_id uuid        NOT NULL,
  status       text        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'accepted')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS follows_following_id_idx ON follows (following_id);
CREATE INDEX IF NOT EXISTS follows_follower_id_idx  ON follows (follower_id);

-- ── stories ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stories (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL,
  photo_url  text        NOT NULL,
  caption    text,
  country_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stories_user_id_idx        ON stories (user_id);
CREATE INDEX IF NOT EXISTS stories_created_at_idx     ON stories (created_at DESC);

-- ── profiles.passport_visibility ─────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS passport_visibility text NOT NULL DEFAULT 'followers'
    CHECK (passport_visibility IN ('public', 'followers', 'private'));

-- ── follows RLS ──────────────────────────────────────────────────────────────
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- A user can see follow edges they originated (the people they follow).
DROP POLICY IF EXISTS "follows_select_as_follower" ON follows;
CREATE POLICY "follows_select_as_follower" ON follows
  FOR SELECT USING (auth.uid() = follower_id);

-- A user can see follow edges pointing at them (their followers / requests).
DROP POLICY IF EXISTS "follows_select_as_following" ON follows;
CREATE POLICY "follows_select_as_following" ON follows
  FOR SELECT USING (auth.uid() = following_id);

-- A user can create a follow edge only as the follower.
DROP POLICY IF EXISTS "follows_insert_own" ON follows;
CREATE POLICY "follows_insert_own" ON follows
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

-- The follower can update their own edge; the target can accept/decline.
DROP POLICY IF EXISTS "follows_update_party" ON follows;
CREATE POLICY "follows_update_party" ON follows
  FOR UPDATE USING (auth.uid() = follower_id OR auth.uid() = following_id)
  WITH CHECK (auth.uid() = follower_id OR auth.uid() = following_id);

-- The follower can delete (unfollow); the target can delete (decline/remove).
DROP POLICY IF EXISTS "follows_delete_party" ON follows;
CREATE POLICY "follows_delete_party" ON follows
  FOR DELETE USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- ── stories RLS ──────────────────────────────────────────────────────────────
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

-- Stories are world-readable; the API decides whose stories make the feed.
DROP POLICY IF EXISTS "stories_public_read" ON stories;
CREATE POLICY "stories_public_read" ON stories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "stories_insert_own" ON stories;
CREATE POLICY "stories_insert_own" ON stories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "stories_update_own" ON stories;
CREATE POLICY "stories_update_own" ON stories
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "stories_delete_own" ON stories;
CREATE POLICY "stories_delete_own" ON stories
  FOR DELETE USING (auth.uid() = user_id);
