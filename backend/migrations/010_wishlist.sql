-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Wishlist ("Want to try") bucket list of countries
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the wishlist
-- feature will work.
--
-- This migration is re-runnable: every CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • wishlist — directed bookmark from a user to a country they want to try
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── wishlist ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wishlist (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL,
  country_id uuid        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, country_id)
);

-- The hot read pattern is "newest-first wishlist for this user"; the composite
-- index serves both the per-user filter and the created_at DESC order without
-- a separate sort step.
CREATE INDEX IF NOT EXISTS wishlist_user_created_idx
  ON wishlist (user_id, created_at DESC);

-- ── wishlist RLS ─────────────────────────────────────────────────────────────
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- A user can only see their own wishlist entries.
DROP POLICY IF EXISTS "wishlist_select_own" ON wishlist;
CREATE POLICY "wishlist_select_own" ON wishlist
  FOR SELECT USING (auth.uid() = user_id);

-- A user can only add entries for themselves.
DROP POLICY IF EXISTS "wishlist_insert_own" ON wishlist;
CREATE POLICY "wishlist_insert_own" ON wishlist
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- A user can only remove their own entries.
DROP POLICY IF EXISTS "wishlist_delete_own" ON wishlist;
CREATE POLICY "wishlist_delete_own" ON wishlist
  FOR DELETE USING (auth.uid() = user_id);
