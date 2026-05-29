"""Couples' Culinary Journey API — progress through the curated weekly itinerary.

Every endpoint authenticates via `current_user_id` (the verified Bearer JWT).
The user_id is never read from the request body or query string.

The curated itinerary itself lives in the mobile app as static data; the
backend only persists how many weeks a couple has completed.

Requires migration `005_couples_journey.sql` (table `couples_journey`). Reads
degrade gracefully — a not-yet-migrated DB returns `completed_weeks: 0` rather
than 500-ing.
"""

import random
from datetime import datetime, timezone

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


# ─── Partner linking ─────────────────────────────────────────────────────────
#
# Requires migration `014_couples.sql` (table `couples`). All read paths
# degrade gracefully when the table is missing so the rest of the app still
# loads on a partially-migrated environment.


def _fetch_active_couple(sb, user_id: str) -> dict | None:
    """Return the single active (pending|accepted) couple row touching user_id,
    or None when there isn't one (or the table doesn't exist yet).
    """
    try:
        res = (
            sb.table("couples")
            .select("*")
            .in_("status", ["pending", "accepted"])
            .or_(f"partner_a_id.eq.{user_id},partner_b_id.eq.{user_id}")
            .limit(1)
            .execute()
        )
    except Exception:
        return None
    rows = res.data or []
    return rows[0] if rows else None


def _hydrate_partner(sb, couple: dict, viewer_id: str) -> dict:
    """Attach the *other* partner's profile (display_name + avatar_url) onto a
    raw couple row, plus a role hint ('a' or 'b') for the viewer.
    """
    partner_id = (
        couple["partner_b_id"]
        if couple["partner_a_id"] == viewer_id
        else couple["partner_a_id"]
    )
    couple["viewer_role"] = "a" if couple["partner_a_id"] == viewer_id else "b"
    couple["partner_id"] = partner_id
    try:
        pres = (
            sb.table("profiles")
            .select("id, display_name, avatar_url")
            .eq("id", partner_id)
            .maybe_single()
            .execute()
        )
        if pres and pres.data:
            couple["partner"] = {
                "user_id": pres.data["id"],
                "display_name": pres.data.get("display_name"),
                "avatar_url": pres.data.get("avatar_url"),
            }
    except Exception:
        # Partner profile lookup is best-effort; the UI falls back to initial.
        couple["partner"] = {"user_id": partner_id}
    return couple


@router.get("/me")
async def my_couple(user_id: str = Depends(current_user_id)):
    """The current user's active couple (or null). Pending invites land here
    too so the UI can show "X invited you" without a separate inbox call.
    """
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple:
        return {"couple": None}
    return {"couple": _hydrate_partner(sb, couple, user_id)}


@router.post("/invite/{target_id}")
async def invite_partner(
    target_id: str,
    user_id: str = Depends(current_user_id),
):
    """Send a couple invite to another user. Both sides must currently have
    no active couple. Drops a `couple_invite` notification on the target.
    """
    if target_id == user_id:
        raise HTTPException(400, "You can't invite yourself.")

    sb = get_supabase()

    # Reject if either side is already linked.
    if _fetch_active_couple(sb, user_id) is not None:
        raise HTTPException(409, "You're already in a couple — unlink first.")
    if _fetch_active_couple(sb, target_id) is not None:
        raise HTTPException(409, "That person is already in another couple.")

    # Verify target exists.
    try:
        prof = (
            sb.table("profiles")
            .select("id, display_name")
            .eq("id", target_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        prof = None
    if not (prof and prof.data):
        raise HTTPException(404, "User not found.")

    try:
        res = (
            sb.table("couples")
            .insert(
                {
                    "partner_a_id": user_id,
                    "partner_b_id": target_id,
                    "status": "pending",
                }
            )
            .execute()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create invite: {e}")

    couple_id = (res.data or [{}])[0].get("id")

    enqueue_notification(
        sb,
        user_id=target_id,
        actor_id=user_id,
        type="couple_invite",
        payload={"couple_id": couple_id},
    )

    return {"couple_id": couple_id, "status": "pending"}


@router.post("/accept")
async def accept_couple(user_id: str = Depends(current_user_id)):
    """Accept the pending invite addressed to the current user, if any."""
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple:
        raise HTTPException(404, "No pending couple invite.")
    if couple["partner_b_id"] != user_id:
        # Inviter trying to accept their own outgoing invite is a no-op.
        raise HTTPException(403, "Only the invitee can accept this invite.")
    if couple["status"] != "pending":
        return {"couple_id": couple["id"], "status": couple["status"]}

    try:
        sb.table("couples").update(
            {"status": "accepted", "accepted_at": "now()"}
        ).eq("id", couple["id"]).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to accept invite: {e}")

    enqueue_notification(
        sb,
        user_id=couple["partner_a_id"],
        actor_id=user_id,
        type="couple_accepted",
        payload={"couple_id": couple["id"]},
    )

    return {"couple_id": couple["id"], "status": "accepted"}


@router.post("/decline")
async def decline_couple(user_id: str = Depends(current_user_id)):
    """Decline a pending invite. Marks the row as ended so the inviter can
    send a fresh invite to someone else without the unique-index blocking.
    """
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple:
        raise HTTPException(404, "No pending couple invite.")
    if couple["status"] != "pending":
        raise HTTPException(409, "Couple is already accepted; use unlink to end.")

    try:
        sb.table("couples").update(
            {"status": "ended", "ended_at": "now()"}
        ).eq("id", couple["id"]).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to decline: {e}")
    return {"declined": True}


@router.delete("/me")
async def unlink_couple(user_id: str = Depends(current_user_id)):
    """End the current user's active couple. Notifies the partner."""
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple:
        return {"unlinked": False, "reason": "no active couple"}

    other = (
        couple["partner_b_id"]
        if couple["partner_a_id"] == user_id
        else couple["partner_a_id"]
    )

    try:
        sb.table("couples").update(
            {"status": "ended", "ended_at": "now()"}
        ).eq("id", couple["id"]).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to unlink: {e}")

    enqueue_notification(
        sb,
        user_id=other,
        actor_id=user_id,
        type="couple_ended",
        payload={"couple_id": couple["id"]},
    )

    return {"unlinked": True}


@router.get("/stats")
async def couple_stats(user_id: str = Depends(current_user_id)):
    """Combined stats for the current couple — joint visits (with_partner=true
    on either side), distinct countries tasted together, distinct cuisines.
    Returns zeroes when there's no active couple or the migrations aren't
    applied. Cheap enough to call from the dashboard on every refresh.

    Also returns:
      • `days_together`  — whole days elapsed since the couple was accepted
                            (always 0 when there's no accepted_at)
      • `first_visit`    — the oldest joint visit's dish_name + country, used
                            by MyCoupleScreen to render a "First plate" memory
    """
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple or couple["status"] != "accepted":
        return {
            "active": False,
            "joint_visits": 0,
            "joint_countries": 0,
            "joint_cuisines": 0,
            "days_together": 0,
            "first_visit": None,
            "since": None,
            "partner": None,
        }

    partner_id = (
        couple["partner_b_id"]
        if couple["partner_a_id"] == user_id
        else couple["partner_a_id"]
    )

    joint_visits = 0
    countries: set[str] = set()
    cuisines: set[str] = set()
    first_visit: dict | None = None
    try:
        res = (
            sb.table("visits")
            .select(
                "id, restaurant_name, country_id, visited_on, created_at, "
                "countries(id, name, flag_emoji, region, subregion)"
            )
            .in_("user_id", [user_id, partner_id])
            .eq("with_partner", True)
            .order("visited_on", desc=False)
            .execute()
        )
        rows = res.data or []
        joint_visits = len(rows)
        for r in rows:
            if r.get("country_id"):
                countries.add(r["country_id"])
            c = r.get("countries") or {}
            sub = c.get("subregion") or c.get("region")
            if sub:
                cuisines.add(sub)
        if rows:
            r0 = rows[0]
            c0 = r0.get("countries") or {}
            first_visit = {
                "visit_id": r0.get("id"),
                "restaurant_name": r0.get("restaurant_name"),
                "country_id": r0.get("country_id"),
                "country_name": c0.get("name"),
                "flag_emoji": c0.get("flag_emoji"),
                # Prefer the user-supplied visited_on (the plate's real date),
                # falling back to created_at when older rows lack it.
                "created_at": r0.get("visited_on") or r0.get("created_at"),
            }
    except Exception:
        # Migration 015 not applied yet — leave counts at zero.
        pass

    days_together = 0
    accepted_at_raw = couple.get("accepted_at")
    if accepted_at_raw:
        try:
            # Postgres timestamptz arrives as ISO-8601 with trailing offset.
            ts = accepted_at_raw
            if isinstance(ts, str) and ts.endswith("Z"):
                ts = ts[:-1] + "+00:00"
            accepted_dt = datetime.fromisoformat(str(ts))
            if accepted_dt.tzinfo is None:
                accepted_dt = accepted_dt.replace(tzinfo=timezone.utc)
            delta = datetime.now(timezone.utc) - accepted_dt
            days_together = max(0, delta.days)
        except Exception:
            days_together = 0

    hydrated = _hydrate_partner(sb, dict(couple), user_id)

    return {
        "active": True,
        "joint_visits": joint_visits,
        "joint_countries": len(countries),
        "joint_cuisines": len(cuisines),
        "days_together": days_together,
        "first_visit": first_visit,
        "since": couple.get("accepted_at") or couple.get("created_at"),
        "partner": hydrated.get("partner"),
    }


# ─── Date Night picker ───────────────────────────────────────────────────────

@router.get("/date-night")
async def date_night(user_id: str = Depends(current_user_id)):
    """Suggest one random country for the couple's next date-night meal.

    Picks from the union of both partners' wishlists, excluding countries
    they've already eaten together. Falls back to a random unvisited (jointly)
    country when neither partner has anything wishlisted.

    Always returns `{ "suggestion": {country_id, country_name, flag_emoji,
    cuisine, reason} | None }`. Returns `None` only when there's no active
    couple, or the database has zero countries.
    """
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple or couple["status"] != "accepted":
        return {"suggestion": None, "reason": "no_active_couple"}

    partner_id = (
        couple["partner_b_id"]
        if couple["partner_a_id"] == user_id
        else couple["partner_a_id"]
    )

    # Countries already tasted jointly — we never resuggest these.
    already_joint: set[str] = set()
    try:
        jres = (
            sb.table("visits")
            .select("country_id")
            .in_("user_id", [user_id, partner_id])
            .eq("with_partner", True)
            .execute()
        )
        for r in jres.data or []:
            cid = r.get("country_id")
            if cid:
                already_joint.add(cid)
    except Exception:
        pass

    # Union of both partners' wishlists.
    wished: set[str] = set()
    try:
        wres = (
            sb.table("wishlist")
            .select("country_id")
            .in_("user_id", [user_id, partner_id])
            .execute()
        )
        for r in wres.data or []:
            cid = r.get("country_id")
            if cid:
                wished.add(cid)
    except Exception:
        pass

    candidates = wished - already_joint
    source = "wishlist"

    # Fall back to "anything you haven't done together yet".
    if not candidates:
        try:
            cres = sb.table("countries").select("id").execute()
            all_ids = {r["id"] for r in (cres.data or []) if r.get("id")}
            candidates = all_ids - already_joint
            source = "anywhere"
        except Exception:
            candidates = set()

    if not candidates:
        return {"suggestion": None, "reason": "exhausted"}

    pick_id = random.choice(list(candidates))
    try:
        cdetail = (
            sb.table("countries")
            .select("id, name, flag_emoji, region, subregion")
            .eq("id", pick_id)
            .maybe_single()
            .execute()
        )
    except Exception:
        cdetail = None

    if not (cdetail and cdetail.data):
        return {"suggestion": None, "reason": "lookup_failed"}

    c = cdetail.data
    return {
        "suggestion": {
            "country_id": c["id"],
            "country_name": c.get("name"),
            "flag_emoji": c.get("flag_emoji"),
            "cuisine": c.get("subregion") or c.get("region"),
            "source": source,
        },
        "reason": "ok",
    }
