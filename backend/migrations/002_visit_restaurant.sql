-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Attach a visit to a specific Baku restaurant
-- Run this once in the Supabase SQL editor (or via psql) BEFORE the
-- "visit → specific restaurant" feature will work.
--
-- Until this migration runs, the backend keeps working: it only writes the
-- `restaurant_name` column when a restaurant is actually picked, and reads
-- with `select("*")` so a missing column never breaks existing reads.
--
-- After this migration:
--   • visits gains a nullable `restaurant_name` text column
--   • a visit logged in the Explore flow can name the exact Baku restaurant
--     it happened at, so the Baku map shows the Instax photo on that one
--     restaurant only (not every restaurant of the same cuisine)
-- ─────────────────────────────────────────────────────────────────────────────

-- ── visits.restaurant_name ───────────────────────────────────────────────────
ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS restaurant_name text;
