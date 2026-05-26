-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Weekly Couples' Culinary Journey progress
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the couples'
-- journey feature will persist progress.
--
-- This migration is re-runnable: the CREATE uses IF NOT EXISTS and every
-- policy is dropped before being (re)created.
--
-- After this migration:
--   • couples_journey — one row per user tracking how many weeks of the
--                       curated 8-week itinerary the couple has completed.
--
-- The FastAPI service key bypasses RLS; the API enforces ownership in Python.
-- RLS here is defense-in-depth, in the style of 001_enable_rls.sql.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── couples_journey ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS couples_journey (
  user_id         uuid        PRIMARY KEY,
  completed_weeks int         NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ── couples_journey RLS ──────────────────────────────────────────────────────
ALTER TABLE couples_journey ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "couples_journey_select_own" ON couples_journey;
CREATE POLICY "couples_journey_select_own" ON couples_journey
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "couples_journey_insert_own" ON couples_journey;
CREATE POLICY "couples_journey_insert_own" ON couples_journey
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "couples_journey_update_own" ON couples_journey;
CREATE POLICY "couples_journey_update_own" ON couples_journey
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "couples_journey_delete_own" ON couples_journey;
CREATE POLICY "couples_journey_delete_own" ON couples_journey
  FOR DELETE USING (auth.uid() = user_id);
