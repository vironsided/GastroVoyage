"""Notifications inbox API — list, mark-read, unread-count.

Every endpoint authenticates via `current_user_id` (the verified Bearer JWT).
The user_id is never read from the request body or query string.

Requires migration `007_notifications.sql` (the `notifications` table). All
reads degrade gracefully — a not-yet-migrated DB returns `[]` / `0` rather
than 500-ing the inbox.

Other API modules emit notifications by calling [enqueue_notification]; the
helper swallows every exception so a failed write here can never break the
originating action (a missed follow notif must not break the follow itself).
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/notifications", tags=["notifications"])

# Whitelist of accepted notification types. Mirrors the CHECK constraint in
# migration 007 (extended by 009 with `story_reaction`, by 012 with
# `story_comment`) — listed here so a typo in a caller is caught early instead
# of surfacing as a 500 from the DB.
_NOTIF_TYPES = {
    "follow_request",
    "follow_accepted",
    "story_view",
    "story_reaction",
    "story_comment",
    "journey_week",
    "badge_earned",
}


# ── helpers ──────────────────────────────────────────────────────────────────
def _profile_map(sb, user_ids: list[str]) -> dict[str, dict]:
    """Return {user_id: {display_name, avatar_url}} for the given ids."""
    ids = list({uid for uid in user_ids if uid})
    if not ids:
        return {}
    try:
        res = (
            sb.table("profiles")
            .select("id, display_name, avatar_url")
            .in_("id", ids)
            .execute()
        )
    except Exception:
        return {}
    out: dict[str, dict] = {}
    for row in res.data or []:
        out[row["id"]] = {
            "display_name": row.get("display_name"),
            "avatar_url": row.get("avatar_url"),
        }
    return out


def enqueue_notification(
    sb,
    *,
    user_id: str,
    actor_id: Optional[str],
    type: str,
    payload: Optional[dict] = None,
) -> None:
    """Insert a notification row. Swallows every exception.

    A notification failure must NEVER break the originating action (a missed
    follow notif cannot block the follow itself). Callers can therefore invoke
    this without a try/except wrapper of their own.
    """
    try:
        if not user_id:
            return
        if type not in _NOTIF_TYPES:
            return
        row: dict = {
            "user_id": user_id,
            "type": type,
            "payload": payload or {},
        }
        if actor_id:
            row["actor_id"] = actor_id
        sb.table("notifications").insert(row).execute()
    except Exception:
        # Swallow: the originating endpoint must always succeed even when the
        # notifications table is missing or insert fails for any reason.
        return


# ── endpoints ────────────────────────────────────────────────────────────────
@router.get("")
async def list_notifications(
    limit: int = 50,
    user_id: str = Depends(current_user_id),
):
    """The signed-in user's notifications, newest first.

    Each row carries the joined `actor` profile (display_name + avatar_url)
    when one exists. Degrades to `[]` if the table hasn't been migrated.
    """
    cap = max(1, min(int(limit or 50), 200))

    sb = get_supabase()
    try:
        res = (
            sb.table("notifications")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(cap)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to an empty inbox.
        return []

    rows = res.data or []
    if not rows:
        return []

    profiles = _profile_map(sb, [r.get("actor_id") for r in rows if r.get("actor_id")])

    return [
        {
            "id": r["id"],
            "type": r.get("type"),
            "actor": (
                {
                    "user_id": r["actor_id"],
                    "display_name": profiles.get(r["actor_id"], {}).get("display_name"),
                    "avatar_url": profiles.get(r["actor_id"], {}).get("avatar_url"),
                }
                if r.get("actor_id")
                else None
            ),
            "payload": r.get("payload") or {},
            "read": bool(r.get("read")),
            "created_at": r.get("created_at"),
        }
        for r in rows
    ]


@router.get("/unread_count")
async def unread_count(user_id: str = Depends(current_user_id)):
    """Count of the user's unread notifications. Returns `{count: 0}` on any
    failure (missing table, RLS edge case) so the UI badge can render safely.
    """
    sb = get_supabase()
    try:
        res = (
            sb.table("notifications")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("read", False)
            .execute()
        )
        return {"count": int(res.count or 0)}
    except Exception:
        return {"count": 0}


class MarkReadRequest(BaseModel):
    ids: Optional[list[str]] = None
    all: Optional[bool] = False


@router.post("/mark_read")
async def mark_read(
    body: MarkReadRequest,
    user_id: str = Depends(current_user_id),
):
    """Mark notifications as read. Body is either `{ids: [...]}` or `{all: true}`.

    Always scoped to the caller's own rows — the user_id filter is the
    enforcement boundary; the request body cannot widen it.
    """
    sb = get_supabase()

    if body.all:
        try:
            res = (
                sb.table("notifications")
                .update({"read": True})
                .eq("user_id", user_id)
                .eq("read", False)
                .execute()
            )
            return {"updated": len(res.data or [])}
        except Exception:
            return {"updated": 0}

    ids = [s for s in (body.ids or []) if s]
    if not ids:
        return {"updated": 0}

    try:
        res = (
            sb.table("notifications")
            .update({"read": True})
            .eq("user_id", user_id)
            .in_("id", ids)
            .execute()
        )
        return {"updated": len(res.data or [])}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to mark read: {e}")
