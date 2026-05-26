-- ─────────────────────────────────────────────────────────────────────────────
-- GastroVoyage — Couple notification types
--
-- Extends notifications.type CHECK to allow:
--   couple_invite   — someone wants to link as your partner
--   couple_accepted — your invitee accepted
--   couple_ended    — your partner unlinked the couple
--
-- Idempotent — drops the existing CHECK regardless of its auto-generated
-- name (Postgres renames the constraint on every redefinition, so a literal
-- DROP CONSTRAINT name would only work the first time).
-- ─────────────────────────────────────────────────────────────────────────────

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

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'follow_request',
    'follow_accepted',
    'story_view',
    'story_reaction',
    'story_comment',
    'journey_week',
    'badge_earned',
    'couple_invite',
    'couple_accepted',
    'couple_ended'
  ));
