-- 013_visit_subratings.sql — 4 micro-ratings per visit
--
-- The single 1–5 overall `rating` column on `visits` is augmented with four
-- nullable sub-ratings: atmosphere, service, value, dish (each 1–5). They are
-- nullable so legacy visits and quick-log flows that skip the detailed form
-- continue to work — the UI treats nulls as "not rated".
--
-- Idempotent (uses ADD COLUMN IF NOT EXISTS).

ALTER TABLE visits ADD COLUMN IF NOT EXISTS atmosphere_rating SMALLINT
  CHECK (atmosphere_rating IS NULL OR (atmosphere_rating BETWEEN 1 AND 5));

ALTER TABLE visits ADD COLUMN IF NOT EXISTS service_rating SMALLINT
  CHECK (service_rating IS NULL OR (service_rating BETWEEN 1 AND 5));

ALTER TABLE visits ADD COLUMN IF NOT EXISTS value_rating SMALLINT
  CHECK (value_rating IS NULL OR (value_rating BETWEEN 1 AND 5));

ALTER TABLE visits ADD COLUMN IF NOT EXISTS dish_rating SMALLINT
  CHECK (dish_rating IS NULL OR (dish_rating BETWEEN 1 AND 5));
