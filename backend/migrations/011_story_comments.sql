-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Story comments (Instagram-style handwritten comments on stories)
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the story
-- comments feature will work. Depends on migration 004_social.sql (the
-- `stories` table).
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • story_comments — one row per comment on a story; ordered by created_at
--     (oldest-first when listed). Length-bounded 1..280 chars at the DB.
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql /
-- 008_story_reactions.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── story_comments ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS story_comments (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  story_id   uuid        NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  actor_id   uuid        NOT NULL,
  text       text        NOT NULL CHECK (length(text) BETWEEN 1 AND 280),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS story_comments_story_created_idx
  ON story_comments (story_id, created_at);

CREATE INDEX IF NOT EXISTS story_comments_actor_idx
  ON story_comments (actor_id);

-- ── story_comments RLS ───────────────────────────────────────────────────────
ALTER TABLE story_comments ENABLE ROW LEVEL SECURITY;

-- Comments are world-readable: stories themselves are shared content (see
-- migration 004) and the comments thread piggy-backs on that. Any authenticated
-- caller can read every comment. This keeps feed-level joins simple and
-- mirrors the `stories_public_read` policy in 004.
DROP POLICY IF EXISTS "story_comments_public_read" ON story_comments;
CREATE POLICY "story_comments_public_read" ON story_comments
  FOR SELECT USING (true);

-- An actor can only insert comments authored by themselves.
DROP POLICY IF EXISTS "story_comments_insert_self" ON story_comments;
CREATE POLICY "story_comments_insert_self" ON story_comments
  FOR INSERT WITH CHECK (auth.uid() = actor_id);

-- Comments aren't editable — keep the thread immutable. There is intentionally
-- no UPDATE policy.

-- The commenter can delete their own row; the story owner can delete any
-- comment on their story (moderation). Mirrors the
-- `story_reactions_delete_self_or_owner` pattern.
DROP POLICY IF EXISTS "story_comments_delete_self_or_owner" ON story_comments;
CREATE POLICY "story_comments_delete_self_or_owner" ON story_comments
  FOR DELETE USING (
    auth.uid() = actor_id
    OR EXISTS (
      SELECT 1 FROM stories s
      WHERE s.id = story_comments.story_id
        AND s.user_id = auth.uid()
    )
  );
