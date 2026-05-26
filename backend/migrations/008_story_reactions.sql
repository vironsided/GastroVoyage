-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Story reactions (Instagram-style emoji reactions on stories)
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the story
-- reaction feature will work. Depends on migration 004_social.sql
-- (the `stories` table).
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • story_reactions — one row per (story, actor) pair, recording the emoji
--     the viewer reacted with. Unique on (story_id, actor_id) — re-reacting
--     with a different emoji updates the existing row.
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── story_reactions ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS story_reactions (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  story_id   uuid        NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  actor_id   uuid        NOT NULL,
  emoji      text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (story_id, actor_id)
);

CREATE INDEX IF NOT EXISTS story_reactions_story_created_idx
  ON story_reactions (story_id, created_at DESC);

CREATE INDEX IF NOT EXISTS story_reactions_actor_idx
  ON story_reactions (actor_id);

-- ── story_reactions RLS ──────────────────────────────────────────────────────
ALTER TABLE story_reactions ENABLE ROW LEVEL SECURITY;

-- An actor can see their own reactions; the story owner can see every
-- reaction row attached to a story they own (correlated EXISTS subquery on
-- stories), mirroring the story_views policy in migration 006.
DROP POLICY IF EXISTS "story_reactions_select_self_or_owner" ON story_reactions;
CREATE POLICY "story_reactions_select_self_or_owner" ON story_reactions
  FOR SELECT USING (
    auth.uid() = actor_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id
        AND s.user_id = auth.uid()
    )
  );

-- An actor can only insert rows recording their own reactions.
DROP POLICY IF EXISTS "story_reactions_insert_self" ON story_reactions;
CREATE POLICY "story_reactions_insert_self" ON story_reactions
  FOR INSERT WITH CHECK (auth.uid() = actor_id);

-- An actor can update their own reaction (change emoji); the story owner can
-- update any reaction on their own stories (used for moderation / clears).
DROP POLICY IF EXISTS "story_reactions_update_self_or_owner" ON story_reactions;
CREATE POLICY "story_reactions_update_self_or_owner" ON story_reactions
  FOR UPDATE USING (
    auth.uid() = actor_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id
        AND s.user_id = auth.uid()
    )
  ) WITH CHECK (
    auth.uid() = actor_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id
        AND s.user_id = auth.uid()
    )
  );

-- The actor can delete their own reaction; the story owner can clear any
-- reaction on their own stories.
DROP POLICY IF EXISTS "story_reactions_delete_self_or_owner" ON story_reactions;
CREATE POLICY "story_reactions_delete_self_or_owner" ON story_reactions
  FOR DELETE USING (
    auth.uid() = actor_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_reactions.story_id
        AND s.user_id = auth.uid()
    )
  );
