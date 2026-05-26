-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Story view tracking (Instagram-style "Seen by N")
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the story
-- "Seen by" feature will work. Depends on migration 004_social.sql
-- (the `stories` table).
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • story_views — one row per (story, viewer) pair, recording who saw what
--     and when. Unique on (story_id, viewer_id) — a re-watch is idempotent.
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── story_views ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS story_views (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  story_id   uuid        NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id  uuid        NOT NULL,
  viewed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (story_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS story_views_story_id_idx ON story_views (story_id);

-- ── story_views RLS ──────────────────────────────────────────────────────────
ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;

-- A viewer can see their own view rows; the story owner can see every view
-- row attached to a story they own (correlated EXISTS subquery on stories).
DROP POLICY IF EXISTS "story_views_select_self_or_owner" ON story_views;
CREATE POLICY "story_views_select_self_or_owner" ON story_views
  FOR SELECT USING (
    auth.uid() = viewer_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_views.story_id
        AND s.user_id = auth.uid()
    )
  );

-- A viewer can only insert rows recording their own views.
DROP POLICY IF EXISTS "story_views_insert_self" ON story_views;
CREATE POLICY "story_views_insert_self" ON story_views
  FOR INSERT WITH CHECK (auth.uid() = viewer_id);

-- The viewer can delete their own view rows; the story owner can clear
-- view rows for any of their stories (correlated EXISTS subquery).
DROP POLICY IF EXISTS "story_views_delete_self_or_owner" ON story_views;
CREATE POLICY "story_views_delete_self_or_owner" ON story_views
  FOR DELETE USING (
    auth.uid() = viewer_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_views.story_id
        AND s.user_id = auth.uid()
    )
  );
