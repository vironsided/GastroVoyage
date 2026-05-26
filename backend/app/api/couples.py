"""Couples' Culinary Journey API — progress through the curated weekly itinerary.

Every endpoint authenticates via `current_user_id` (the verified Bearer JWT).
The user_id is never read from the request body or query string.

The curated itinerary itself lives in the mobile app as static data; the
backend only persists how many weeks a couple has completed.

Requires migration `005_couples_journey.sql` (table `couples_journey`). Reads
degrade gracefully — a not-yet-migrated DB returns `completed_weeks: 0` rather
than 500-ing.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.notifications import enqueue_notification
from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/couples", tags=["couples"])


@router.get("/progress")
async def get_progress(user_id: str = Depends(current_user_id)):
    """How many weeks of the couples' journey the current user has completed.

    Returns `{"completed_weeks": 0}` when there is no row yet, and also when
    the `couples_journey` table has not been migrated — so the feature stays
    usable on a partially-migrated environment.
    """
    sb = get_supabase()
    try:
        res = (
            sb.table("couples_journey")
            .select("completed_weeks")
            .eq("user_id", user_id)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to "no progress".
        return {"completed_weeks": 0}

    rows = res.data or []
    if not rows:
        return {"completed_weeks": 0}

    weeks = rows[0].get("completed_weeks") or 0
    return {"completed_weeks": max(0, int(weeks))}


class ProgressUpdate(BaseModel):
    completed_weeks: int


@router.put("/progress")
async def set_progress(body: ProgressUpdate, user_id: str = Depends(current_user_id)):
    """Upsert the current user's couples-journey progress.

    Negative values are clamped to 0. Returns the persisted value. When the
    week count advances, drops a `journey_week` notification into the user's
    own inbox — a celebratory ping for crossing a milestone.
    """
    weeks = max(0, int(body.completed_weeks))

    sb = get_supabase()

    # Read the previous count first so we only fire a notification on actual
    # forward progress (not on idempotent re-saves or rollbacks).
    previous = 0
    try:
        prev_res = (
            sb.table("couples_journey")
            .select("completed_weeks")
            .eq("user_id", user_id)
            .execute()
        )
        if prev_res.data:
            previous = int(prev_res.data[0].get("completed_weeks") or 0)
    except Exception:
        # Table not migrated — treat as no prior progress.
        previous = 0

    try:
        sb.table("couples_journey").upsert(
            {"user_id": user_id, "completed_weeks": weeks},
            on_conflict="user_id",
        ).execute()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save couples-journey progress: {e}",
        )

    if weeks > previous:
        enqueue_notification(
            sb,
            user_id=user_id,
            actor_id=None,
            type="journey_week",
            payload={"week_index": weeks},
        )

    return {"completed_weeks": weeks}
