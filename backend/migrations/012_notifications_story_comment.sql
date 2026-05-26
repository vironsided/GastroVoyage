-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Extend the notifications type CHECK with `story_comment`
-- Run this once in the Supabase SQL editor (or via psql) AFTER migration
-- 007_notifications.sql, 009_notifications_story_reaction.sql, and
-- 011_story_comments.sql. Without this migration the backend silently skips
-- inserting story-comment notifications (the type would fail the CHECK
-- constraint).
--
-- This migration is re-runnable and idempotent: it drops the existing CHECK
-- constraint by name, then loops over `pg_constraint` to drop any other CHECK
-- that still references the `type` column (belt-and-braces for re-runs after
-- the constraint was renamed elsewhere), then re-adds the constraint with the
-- full allow-list including `story_comment`.
--
-- After this migration:
--   • notifications.type accepts the full set:
--       follow_request, follow_accepted, story_view, story_reaction,
--       story_comment, journey_week, badge_earned
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop the auto-named CHECK that earlier migrations created inline (Postgres
-- default = `<table>_<column>_check`). Using IF EXISTS keeps it re-runnable.
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Belt-and-braces: drop any other CHECK constraint that still references the
-- `type` column. (The earlier dynamic filter `ILIKE '%type%IN%'` missed
-- because Postgres normalises `IN (...)` to `= ANY (ARRAY[...])`.)
DO $$
DECLARE
  con_name text;
BEGIN
  FOR con_name IN
    SELECT c.conname
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
     WHERE c.conrelid = 'notifications'::regclass
       AND c.contype  = 'c'
       AND a.attname  = 'type'
  LOOP
    EXECUTE format('ALTER TABLE notifications DROP CONSTRAINT %I', con_name);
  END LOOP;
END$$;

-- Re-add the CHECK with the expanded allow-list. Naming it explicitly so a
-- subsequent migration can target it deterministically if needed.
ALTER TABLE notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'follow_request',
    'follow_accepted',
    'story_view',
    'story_reaction',
    'story_comment',
    'journey_week',
    'badge_earned'
  ));
