"""Social network API — follow graph, privacy, passport inspection, stories.

Every endpoint authenticates via `current_user_id` (the verified Bearer JWT).
The user_id is never read from the request body or query string.

Requires migration `004_social.sql` (tables `follows`, `stories`, and the
`profiles.passport_visibility` column). Reads use `select("*")`-friendly
patterns where reasonable so a not-yet-migrated DB degrades rather than 500s.
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.notifications import enqueue_notification
from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/social", tags=["social"])

_VISIBILITY_VALUES = {"public", "followers", "private"}


# ── helpers ──────────────────────────────────────────────────────────────────
def _profile_map(sb, user_ids: list[str]) -> dict[str, dict]:
    """Return {user_id: {display_name, avatar_url}} for the given ids."""
    ids = list({uid for uid in user_ids if uid})
    if not ids:
        return {}
    res = sb.table("profiles").select("id, display_name, avatar_url").in_("id", ids).execute()
    out: dict[str, dict] = {}
    for row in res.data or []:
        out[row["id"]] = {
            "display_name": row.get("display_name"),
            "avatar_url": row.get("avatar_url"),
        }
    return out


def _view_count_map(sb, story_ids: list[str]) -> dict[str, int]:
    """Return {story_id: view_count} for the given story ids.

    One query returns every matching view row; we then count in Python so a
    not-yet-migrated DB (no `story_views` table) degrades to an empty map
    rather than 500-ing the feed.
    """
    ids = list({sid for sid in story_ids if sid})
    if not ids:
        return {}
    try:
        res = sb.table("story_views").select("story_id").in_("story_id", ids).execute()
    except Exception:
        return {}
    counts: dict[str, int] = {}
    for row in res.data or []:
        sid = row.get("story_id")
        if not sid:
            continue
        counts[sid] = counts.get(sid, 0) + 1
    return counts


def _reaction_count_map(sb, story_ids: list[str]) -> dict[str, int]:
    """Return {story_id: reaction_count} for the given story ids.

    Degrades to an empty map when the `story_reactions` table hasn't been
    migrated yet — the feed must never 500 just because reactions are off.
    """
    ids = list({sid for sid in story_ids if sid})
    if not ids:
        return {}
    try:
        res = (
            sb.table("story_reactions")
            .select("story_id")
            .in_("story_id", ids)
            .execute()
        )
    except Exception:
        return {}
    counts: dict[str, int] = {}
    for row in res.data or []:
        sid = row.get("story_id")
        if not sid:
            continue
        counts[sid] = counts.get(sid, 0) + 1
    return counts


def _comment_count_map(sb, story_ids: list[str]) -> dict[str, int]:
    """Return {story_id: comment_count} for the given story ids.

    Degrades to an empty map when the `story_comments` table hasn't been
    migrated yet — the feed must never 500 just because comments are off.
    Mirrors `_view_count_map` / `_reaction_count_map`.
    """
    ids = list({sid for sid in story_ids if sid})
    if not ids:
        return {}
    try:
        res = (
            sb.table("story_comments")
            .select("story_id")
            .in_("story_id", ids)
            .execute()
        )
    except Exception:
        return {}
    counts: dict[str, int] = {}
    for row in res.data or []:
        sid = row.get("story_id")
        if not sid:
            continue
        counts[sid] = counts.get(sid, 0) + 1
    return counts


def _my_reaction_map(
    sb, story_ids: list[str], actor_id: str
) -> dict[str, str]:
    """Return {story_id: emoji} for the caller's reactions on the given stories.

    Degrades to an empty map when the `story_reactions` table hasn't been
    migrated yet, mirroring the other reaction helpers.
    """
    ids = list({sid for sid in story_ids if sid})
    if not ids or not actor_id:
        return {}
    try:
        res = (
            sb.table("story_reactions")
            .select("story_id, emoji")
            .in_("story_id", ids)
            .eq("actor_id", actor_id)
            .execute()
        )
    except Exception:
        return {}
    out: dict[str, str] = {}
    for row in res.data or []:
        sid = row.get("story_id")
        emoji = row.get("emoji")
        if sid and emoji:
            out[sid] = emoji
    return out


def _country_map(sb, country_ids: list[str]) -> dict[str, dict]:
    """Return {country_id: country_row} for the given ids."""
    ids = list({cid for cid in country_ids if cid})
    if not ids:
        return {}
    res = (
        sb.table("countries")
        .select("id, name, iso_a2, flag_emoji, region")
        .in_("id", ids)
        .execute()
    )
    return {row["id"]: row for row in (res.data or [])}


# ── follow graph ─────────────────────────────────────────────────────────────
class FollowRequest(BaseModel):
    following_id: str


@router.post("/follow")
async def follow_user(body: FollowRequest, user_id: str = Depends(current_user_id)):
    """Create (or no-op on) a follow edge me → following_id with status 'pending'.

    Returns the edge's current status. Following yourself is rejected (400).
    """
    following_id = (body.following_id or "").strip()
    if not following_id:
        raise HTTPException(status_code=400, detail="following_id is required")
    if following_id == user_id:
        raise HTTPException(status_code=400, detail="You cannot follow yourself")

    sb = get_supabase()

    existing = (
        sb.table("follows")
        .select("status")
        .eq("follower_id", user_id)
        .eq("following_id", following_id)
        .execute()
    )
    if existing.data:
        # Already followed or already requested — no new notification.
        return {"status": existing.data[0]["status"]}

    try:
        res = (
            sb.table("follows")
            .insert(
                {
                    "follower_id": user_id,
                    "following_id": following_id,
                    "status": "pending",
                }
            )
            .execute()
        )
    except Exception:
        # Lost an insert race against the unique constraint — read the winner.
        again = (
            sb.table("follows")
            .select("status")
            .eq("follower_id", user_id)
            .eq("following_id", following_id)
            .execute()
        )
        if again.data:
            return {"status": again.data[0]["status"]}
        raise HTTPException(status_code=500, detail="Failed to create follow request")

    status = res.data[0]["status"] if res.data else "pending"
    # Notify the target. A brand-new edge always starts pending in the current
    # spec, but stay defensive: emit `follow_accepted` if a future variant ever
    # auto-accepts public-profile follows.
    enqueue_notification(
        sb,
        user_id=following_id,
        actor_id=user_id,
        type="follow_accepted" if status == "accepted" else "follow_request",
        payload={},
    )
    return {"status": status}


@router.delete("/follow/{following_id}")
async def unfollow_user(following_id: str, user_id: str = Depends(current_user_id)):
    """Delete my follow edge to `following_id` (unfollow or cancel a request)."""
    sb = get_supabase()
    sb.table("follows").delete().eq("follower_id", user_id).eq(
        "following_id", following_id
    ).execute()
    return {"deleted": True}


@router.post("/follow/{follower_id}/accept")
async def accept_follow(follower_id: str, user_id: str = Depends(current_user_id)):
    """Accept a pending follow request from `follower_id` (they → me)."""
    sb = get_supabase()
    existing = (
        sb.table("follows")
        .select("id")
        .eq("follower_id", follower_id)
        .eq("following_id", user_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Follow request not found")

    sb.table("follows").update({"status": "accepted"}).eq(
        "follower_id", follower_id
    ).eq("following_id", user_id).execute()
    # Let the original requester know their request was accepted.
    enqueue_notification(
        sb,
        user_id=follower_id,
        actor_id=user_id,
        type="follow_accepted",
        payload={},
    )
    return {"status": "accepted"}


@router.post("/follow/{follower_id}/decline")
async def decline_follow(follower_id: str, user_id: str = Depends(current_user_id)):
    """Decline / remove a follow edge from `follower_id` (they → me)."""
    sb = get_supabase()
    existing = (
        sb.table("follows")
        .select("id")
        .eq("follower_id", follower_id)
        .eq("following_id", user_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Follow request not found")

    sb.table("follows").delete().eq("follower_id", follower_id).eq(
        "following_id", user_id
    ).execute()
    return {"declined": True}


@router.get("/following")
async def list_following(user_id: str = Depends(current_user_id)):
    """Users I follow, with the edge status (pending/accepted)."""
    sb = get_supabase()
    edges = (
        sb.table("follows")
        .select("following_id, status, created_at")
        .eq("follower_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    rows = edges.data or []
    profiles = _profile_map(sb, [r["following_id"] for r in rows])
    return [
        {
            "user_id": r["following_id"],
            "display_name": profiles.get(r["following_id"], {}).get("display_name"),
            "avatar_url": profiles.get(r["following_id"], {}).get("avatar_url"),
            "status": r["status"],
        }
        for r in rows
    ]


@router.get("/followers")
async def list_followers(user_id: str = Depends(current_user_id)):
    """Users who follow me, including pending requests (client splits by status)."""
    sb = get_supabase()
    edges = (
        sb.table("follows")
        .select("follower_id, status, created_at")
        .eq("following_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    rows = edges.data or []
    profiles = _profile_map(sb, [r["follower_id"] for r in rows])
    return [
        {
            "user_id": r["follower_id"],
            "display_name": profiles.get(r["follower_id"], {}).get("display_name"),
            "avatar_url": profiles.get(r["follower_id"], {}).get("avatar_url"),
            "status": r["status"],
        }
        for r in rows
    ]


@router.get("/users/search")
async def search_users(q: str = "", user_id: str = Depends(current_user_id)):
    """Search profiles by display_name (ILIKE %q%), excluding myself.

    `follow_status` is my relationship to each result: none|pending|accepted.
    """
    term = (q or "").strip()
    if not term:
        return []

    sb = get_supabase()
    # Escape PostgREST ILIKE wildcards so a literal % or _ is matched literally.
    safe = term.replace("%", r"\%").replace("_", r"\_")
    res = (
        sb.table("profiles")
        .select("id, display_name, avatar_url")
        .ilike("display_name", f"%{safe}%")
        .neq("id", user_id)
        .limit(20)
        .execute()
    )
    rows = res.data or []
    if not rows:
        return []

    edges = (
        sb.table("follows")
        .select("following_id, status")
        .eq("follower_id", user_id)
        .in_("following_id", [r["id"] for r in rows])
        .execute()
    )
    status_by_id = {e["following_id"]: e["status"] for e in (edges.data or [])}

    return [
        {
            "user_id": r["id"],
            "display_name": r.get("display_name"),
            "avatar_url": r.get("avatar_url"),
            "follow_status": status_by_id.get(r["id"], "none"),
        }
        for r in rows
    ]


# ── privacy ──────────────────────────────────────────────────────────────────
@router.get("/privacy")
async def get_privacy(user_id: str = Depends(current_user_id)):
    """My passport visibility setting."""
    sb = get_supabase()
    res = sb.table("profiles").select("*").eq("id", user_id).single().execute()
    profile = res.data or {}
    return {"passport_visibility": profile.get("passport_visibility") or "followers"}


class PrivacyUpdate(BaseModel):
    passport_visibility: str


@router.patch("/privacy")
async def update_privacy(body: PrivacyUpdate, user_id: str = Depends(current_user_id)):
    """Update my passport visibility (public | followers | private)."""
    value = (body.passport_visibility or "").strip().lower()
    if value not in _VISIBILITY_VALUES:
        raise HTTPException(
            status_code=400,
            detail="passport_visibility must be one of: public, followers, private",
        )
    sb = get_supabase()
    sb.table("profiles").update({"passport_visibility": value}).eq("id", user_id).execute()
    return {"passport_visibility": value}


# ── passport inspection ──────────────────────────────────────────────────────
@router.get("/passport/{target_id}")
async def get_passport(target_id: str, user_id: str = Depends(current_user_id)):
    """Inspect another user's passport, gated by their visibility setting.

    Allowed when: it's my own passport, OR the target is 'public', OR the
    target is 'followers' and I have an accepted follow edge to them.
    Otherwise 403.
    """
    sb = get_supabase()

    profile_res = sb.table("profiles").select("*").eq("id", target_id).execute()
    if not profile_res.data:
        raise HTTPException(status_code=404, detail="User not found")
    profile = profile_res.data[0]
    visibility = profile.get("passport_visibility") or "followers"

    if target_id != user_id:
        if visibility == "private":
            raise HTTPException(status_code=403, detail="This passport is private")
        if visibility == "followers":
            edge = (
                sb.table("follows")
                .select("status")
                .eq("follower_id", user_id)
                .eq("following_id", target_id)
                .eq("status", "accepted")
                .execute()
            )
            if not edge.data:
                raise HTTPException(
                    status_code=403,
                    detail="This passport is visible to followers only",
                )

    visits_res = (
        sb.table("visits")
        .select("*")
        .eq("user_id", target_id)
        .order("visited_on", desc=True)
        .execute()
    )
    visit_rows = visits_res.data or []

    country_ids = [v["country_id"] for v in visit_rows if v.get("country_id")]
    countries = _country_map(sb, country_ids)

    try:
        badge_res = (
            sb.table("user_badges")
            .select("badge_code", count="exact")
            .eq("user_id", target_id)
            .execute()
        )
        badge_count = badge_res.count or 0
    except Exception:
        badge_count = 0

    distinct_country_ids: list[str] = []
    seen: set[str] = set()
    for cid in country_ids:
        if cid not in seen:
            seen.add(cid)
            distinct_country_ids.append(cid)

    return {
        "user_id": target_id,
        "display_name": profile.get("display_name"),
        "avatar_url": profile.get("avatar_url"),
        "passport_visibility": visibility,
        "visited_count": len(distinct_country_ids),
        "badge_count": badge_count,
        "countries": [
            {
                "id": cid,
                "name": countries.get(cid, {}).get("name"),
                "iso_a2": countries.get(cid, {}).get("iso_a2"),
                "flag_emoji": countries.get(cid, {}).get("flag_emoji"),
                "region": countries.get(cid, {}).get("region"),
            }
            for cid in distinct_country_ids
        ],
        "visits": [
            {
                "id": v["id"],
                "country_id": v.get("country_id"),
                "country_name": countries.get(v.get("country_id"), {}).get("name"),
                "rating": v.get("rating"),
                "notes": v.get("notes"),
                "visited_on": v.get("visited_on"),
                "photo_path": v.get("photo_path"),
                "restaurant_name": v.get("restaurant_name"),
            }
            for v in visit_rows
        ],
    }


# ── stories feed ─────────────────────────────────────────────────────────────
class StoryCreate(BaseModel):
    photo_url: str
    caption: Optional[str] = None
    country_id: Optional[str] = None


@router.post("/stories")
async def create_story(body: StoryCreate, user_id: str = Depends(current_user_id)):
    """Post a new story for me. Returns the created story row."""
    photo_url = (body.photo_url or "").strip()
    if not photo_url:
        raise HTTPException(status_code=400, detail="photo_url is required")

    sb = get_supabase()
    row: dict = {"user_id": user_id, "photo_url": photo_url}
    if body.caption is not None:
        row["caption"] = body.caption
    if body.country_id:
        row["country_id"] = body.country_id

    try:
        res = sb.table("stories").insert(row).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create story: {e}")

    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to create story")
    # A brand-new story has zero views, reactions, and comments; surface the
    # fields so the mobile model can render its "Seen by N · 🍴3 · 💬0" pill
    # straight away without a feed refetch.
    created = dict(res.data[0])
    created.setdefault("view_count", 0)
    created.setdefault("reaction_count", 0)
    created.setdefault("comment_count", 0)
    created.setdefault("my_reaction", None)
    return created


@router.get("/feed")
async def get_feed(user_id: str = Depends(current_user_id)):
    """Stories from me and everyone I follow with an accepted edge, newest first."""
    sb = get_supabase()

    edges = (
        sb.table("follows")
        .select("following_id")
        .eq("follower_id", user_id)
        .eq("status", "accepted")
        .execute()
    )
    author_ids = {e["following_id"] for e in (edges.data or [])}
    author_ids.add(user_id)

    try:
        stories_res = (
            sb.table("stories")
            .select("*")
            .in_("user_id", list(author_ids))
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
    except Exception:
        # stories table not migrated yet — degrade to an empty feed.
        return []

    rows = stories_res.data or []
    if not rows:
        return []

    profiles = _profile_map(sb, [r["user_id"] for r in rows])
    countries = _country_map(sb, [r.get("country_id") for r in rows])

    # Count views & reactions only for the caller's OWN stories. Non-owners
    # don't get to see who saw or reacted to someone else's story, so we
    # leave those counts at 0 and the mobile UI hides the badge accordingly.
    own_story_ids = [r["id"] for r in rows if r.get("user_id") == user_id]
    view_counts = _view_count_map(sb, own_story_ids)
    reaction_counts = _reaction_count_map(sb, own_story_ids)

    # Comments are the only public counter — anyone can see how many comments
    # a story has, because the comments thread is open to everyone.
    all_story_ids = [r["id"] for r in rows]
    comment_counts = _comment_count_map(sb, all_story_ids)

    # The caller's OWN reaction on every story they can see in the feed —
    # rendered as a highlight on the reaction palette in the story viewer.
    my_reactions = _my_reaction_map(sb, all_story_ids, user_id)

    return [
        {
            "id": r["id"],
            "user_id": r["user_id"],
            "display_name": profiles.get(r["user_id"], {}).get("display_name"),
            "avatar_url": profiles.get(r["user_id"], {}).get("avatar_url"),
            "photo_url": r.get("photo_url"),
            "caption": r.get("caption"),
            "country_id": r.get("country_id"),
            "country_name": countries.get(r.get("country_id"), {}).get("name"),
            "created_at": r.get("created_at"),
            "view_count": view_counts.get(r["id"], 0)
            if r.get("user_id") == user_id
            else 0,
            "reaction_count": reaction_counts.get(r["id"], 0)
            if r.get("user_id") == user_id
            else 0,
            "comment_count": comment_counts.get(r["id"], 0),
            "my_reaction": my_reactions.get(r["id"]),
        }
        for r in rows
    ]


# ── story views ──────────────────────────────────────────────────────────────
@router.post("/stories/{story_id}/view")
async def mark_story_viewed(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """Record that the caller saw [story_id]. Idempotent on (story_id, viewer_id).

    Viewing your own story does not produce a view row — Instagram-style, the
    owner's view doesn't count toward "Seen by N". 404 if the story is gone.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()

    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    owner_id = story_res.data[0].get("user_id")

    # Owners viewing their own story don't create a view row.
    if owner_id == user_id:
        return {"viewed": True}

    try:
        sb.table("story_views").upsert(
            {"story_id": sid, "viewer_id": user_id},
            on_conflict="story_id,viewer_id",
        ).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to record view: {e}")

    # Notify the owner — but only once per (story, viewer) pair. Re-watching
    # the same story by the same viewer must not spam the inbox. Best-effort:
    # any lookup failure (e.g. notifications table not migrated) just skips
    # the notification, never the view record itself.
    try:
        prior = (
            sb.table("notifications")
            .select("id")
            .eq("user_id", owner_id)
            .eq("actor_id", user_id)
            .eq("type", "story_view")
            .eq("payload->>story_id", sid)
            .limit(1)
            .execute()
        )
        already_notified = bool(prior.data)
    except Exception:
        already_notified = False

    if not already_notified:
        enqueue_notification(
            sb,
            user_id=owner_id,
            actor_id=user_id,
            type="story_view",
            payload={"story_id": sid},
        )

    return {"viewed": True}


@router.get("/stories/{story_id}/viewers")
async def list_story_viewers(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """Viewer list for [story_id], owner-only. Returns newest-first viewer rows
    joined with `profiles`. 403 for non-owners, 404 if the story is gone.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()

    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    if story_res.data[0].get("user_id") != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only the story owner can see who viewed this story",
        )

    try:
        views_res = (
            sb.table("story_views")
            .select("viewer_id, viewed_at")
            .eq("story_id", sid)
            .order("viewed_at", desc=True)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to empty so the sheet shows
        # "no one's peeked yet" instead of crashing.
        return []

    rows = views_res.data or []
    if not rows:
        return []

    profiles = _profile_map(sb, [r["viewer_id"] for r in rows])
    return [
        {
            "user_id": r["viewer_id"],
            "display_name": profiles.get(r["viewer_id"], {}).get("display_name"),
            "avatar_url": profiles.get(r["viewer_id"], {}).get("avatar_url"),
            "viewed_at": r.get("viewed_at"),
        }
        for r in rows
    ]


@router.get("/stories/{story_id}/view_count")
async def get_story_view_count(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """Helper for one-off view-count reads. Owners get the real count; everyone
    else gets 0 so the field is always safe to render without a 403.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()
    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    if story_res.data[0].get("user_id") != user_id:
        return {"count": 0}

    try:
        res = (
            sb.table("story_views")
            .select("id", count="exact")
            .eq("story_id", sid)
            .execute()
        )
        return {"count": res.count or 0}
    except Exception:
        return {"count": 0}


# ── story reactions ──────────────────────────────────────────────────────────
class StoryReactionRequest(BaseModel):
    emoji: str


def _normalise_emoji(raw: str) -> str:
    """Strip whitespace and clamp to a single visible grapheme.

    We accept any single emoji on the wire (the mobile UI offers a curated
    palette of food-themed glyphs, but the backend stays agnostic). The
    16-character ceiling is a defensive cap on multi-codepoint emoji
    sequences (skin-tone, ZWJ, regional indicators) — well above any single
    grapheme but small enough to keep the column bounded.
    """
    value = (raw or "").strip()
    if not value:
        return ""
    if len(value) > 16:
        return ""
    return value


@router.post("/stories/{story_id}/react")
async def react_to_story(
    story_id: str,
    body: StoryReactionRequest,
    user_id: str = Depends(current_user_id),
):
    """Upsert the caller's reaction emoji on [story_id].

    One reaction per (story, actor) — re-reacting with a different emoji
    replaces the prior one. Reacting to your own story succeeds silently
    without enqueuing a notification.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    emoji = _normalise_emoji(body.emoji)
    if not emoji:
        raise HTTPException(status_code=400, detail="emoji is required")

    sb = get_supabase()

    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    owner_id = story_res.data[0].get("user_id")

    try:
        sb.table("story_reactions").upsert(
            {
                "story_id": sid,
                "actor_id": user_id,
                "emoji": emoji,
            },
            on_conflict="story_id,actor_id",
        ).execute()
    except Exception as e:
        # Most likely the migration hasn't run. Degrade to a 503 so the mobile
        # client can show a sensible "reactions aren't enabled yet" toast
        # rather than a crash.
        raise HTTPException(
            status_code=503,
            detail=f"Reactions are not available yet: {e}",
        )

    # Reacting to your own story doesn't notify yourself.
    if owner_id == user_id:
        return {"emoji": emoji}

    # Notify the owner — but de-dup per (story, actor) like `story_view`.
    # If a prior story_reaction notif exists for the same pair, refresh its
    # payload (new emoji) and bump it back to unread so the inbox surfaces
    # the change without duplicate rows.
    try:
        prior = (
            sb.table("notifications")
            .select("id")
            .eq("user_id", owner_id)
            .eq("actor_id", user_id)
            .eq("type", "story_reaction")
            .eq("payload->>story_id", sid)
            .limit(1)
            .execute()
        )
        prior_rows = prior.data or []
    except Exception:
        prior_rows = []

    if prior_rows:
        try:
            sb.table("notifications").update(
                {
                    "payload": {"story_id": sid, "emoji": emoji},
                    "read": False,
                }
            ).eq("id", prior_rows[0]["id"]).execute()
        except Exception:
            # Update fail is non-fatal; the original notif still exists.
            pass
    else:
        enqueue_notification(
            sb,
            user_id=owner_id,
            actor_id=user_id,
            type="story_reaction",
            payload={"story_id": sid, "emoji": emoji},
        )

    return {"emoji": emoji}


@router.delete("/stories/{story_id}/react")
async def unreact_to_story(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """Delete the caller's reaction on [story_id]. Idempotent."""
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()
    try:
        sb.table("story_reactions").delete().eq("story_id", sid).eq(
            "actor_id", user_id
        ).execute()
    except Exception:
        # Table not migrated yet — nothing to delete; report success so the
        # mobile UI's optimistic clear stays in sync.
        return {"deleted": True}
    return {"deleted": True}


@router.get("/stories/{story_id}/reactions")
async def list_story_reactions(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """Reactions on [story_id], owner-only. Newest-first, joined with profiles.

    Degrades to `[]` if the `story_reactions` table hasn't been migrated yet.
    403 for non-owners, 404 if the story is gone.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()

    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    if story_res.data[0].get("user_id") != user_id:
        raise HTTPException(
            status_code=403,
            detail="Only the story owner can see who reacted to this story",
        )

    try:
        rxn_res = (
            sb.table("story_reactions")
            .select("actor_id, emoji, created_at")
            .eq("story_id", sid)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to empty so the sheet shows an
        # "no reactions yet" state instead of crashing.
        return []

    rows = rxn_res.data or []
    if not rows:
        return []

    profiles = _profile_map(sb, [r["actor_id"] for r in rows])
    return [
        {
            "actor": {
                "user_id": r["actor_id"],
                "display_name": profiles.get(r["actor_id"], {}).get("display_name"),
                "avatar_url": profiles.get(r["actor_id"], {}).get("avatar_url"),
            },
            "emoji": r.get("emoji"),
            "created_at": r.get("created_at"),
        }
        for r in rows
    ]


# ── story comments ───────────────────────────────────────────────────────────
class StoryCommentRequest(BaseModel):
    text: str


# A comment from the same actor on the same story inside this window is
# considered a "burst" and won't enqueue a fresh notification — keeps the
# owner's inbox from being spammed if the viewer fires off three quick
# comments. The comment row itself is still saved.
_COMMENT_NOTIF_WINDOW_SECONDS = 5 * 60


@router.post("/stories/{story_id}/comment")
async def comment_on_story(
    story_id: str,
    body: StoryCommentRequest,
    user_id: str = Depends(current_user_id),
):
    """Post a comment on [story_id]. Returns the inserted row with the actor
    profile joined in. Validates length 1..280 chars after trim.

    The story owner is notified at most once per (story, actor) per 5 minutes
    so a burst of rapid-fire comments doesn't spam the inbox. The comment row
    is always saved; only the *notification* is rate-limited.

    Degrades to 503 when the `story_comments` table hasn't been migrated.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    text = (body.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Comment cannot be empty")
    if len(text) > 280:
        raise HTTPException(
            status_code=400,
            detail="Comment must be 280 characters or fewer",
        )

    sb = get_supabase()

    story_res = sb.table("stories").select("user_id").eq("id", sid).execute()
    if not story_res.data:
        raise HTTPException(status_code=404, detail="Story not found")
    owner_id = story_res.data[0].get("user_id")

    try:
        res = (
            sb.table("story_comments")
            .insert(
                {
                    "story_id": sid,
                    "actor_id": user_id,
                    "text": text,
                }
            )
            .execute()
        )
    except Exception as e:
        # Most likely the migration hasn't run yet. Degrade to a 503 so the
        # mobile client can show a "comments aren't enabled yet" toast rather
        # than crashing.
        raise HTTPException(
            status_code=503,
            detail=f"Comments are not available yet: {e}",
        )

    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to save comment")

    row = res.data[0]
    profiles = _profile_map(sb, [user_id])
    actor_profile = profiles.get(user_id, {})

    # Owner-comments-on-own-story doesn't enqueue a notification.
    if owner_id and owner_id != user_id:
        # Burst de-dup: don't enqueue a fresh notification if we already sent
        # one for this (story, actor) pair inside the recent window. Best
        # effort — any lookup failure (table missing) just falls through to
        # the unconditional enqueue helper below, which itself swallows.
        should_enqueue = True
        try:
            from datetime import datetime, timedelta, timezone

            cutoff = (
                datetime.now(timezone.utc)
                - timedelta(seconds=_COMMENT_NOTIF_WINDOW_SECONDS)
            ).isoformat()
            prior = (
                sb.table("notifications")
                .select("id")
                .eq("user_id", owner_id)
                .eq("actor_id", user_id)
                .eq("type", "story_comment")
                .eq("payload->>story_id", sid)
                .gte("created_at", cutoff)
                .limit(1)
                .execute()
            )
            if prior.data:
                should_enqueue = False
        except Exception:
            should_enqueue = True

        if should_enqueue:
            # Trim the preview so the inbox row stays readable. The full
            # comment is in the thread itself; the notification just hints
            # at what the new comment said.
            preview = text if len(text) <= 80 else (text[:77] + "…")
            enqueue_notification(
                sb,
                user_id=owner_id,
                actor_id=user_id,
                type="story_comment",
                payload={"story_id": sid, "text": preview},
            )

    return {
        "id": row["id"],
        "actor": {
            "user_id": user_id,
            "display_name": actor_profile.get("display_name"),
            "avatar_url": actor_profile.get("avatar_url"),
        },
        "text": row.get("text") or text,
        "created_at": row.get("created_at"),
    }


@router.delete("/stories/comments/{comment_id}")
async def delete_story_comment(
    comment_id: str, user_id: str = Depends(current_user_id)
):
    """Delete a comment. Only the commenter or the story owner can delete.
    404 if the comment doesn't exist. Idempotent only for the same caller —
    a second delete returns 404 because the row is gone.
    """
    cid = (comment_id or "").strip()
    if not cid:
        raise HTTPException(status_code=400, detail="comment_id is required")

    sb = get_supabase()

    try:
        comment_res = (
            sb.table("story_comments")
            .select("id, story_id, actor_id")
            .eq("id", cid)
            .execute()
        )
    except Exception:
        # Table not migrated yet — there's nothing to delete; report 404 so
        # the mobile UI shows a friendly "this comment is gone" state.
        raise HTTPException(status_code=404, detail="Comment not found")

    if not comment_res.data:
        raise HTTPException(status_code=404, detail="Comment not found")

    comment = comment_res.data[0]
    actor_id = comment.get("actor_id")
    story_id = comment.get("story_id")

    # Lookup the story owner so we can authorise deletion. A missing story is
    # treated as "anyone with the comment id can delete" — but the cascade
    # FK on story_comments.story_id means that should never happen.
    owner_id: Optional[str] = None
    if story_id:
        try:
            story_res = (
                sb.table("stories").select("user_id").eq("id", story_id).execute()
            )
            if story_res.data:
                owner_id = story_res.data[0].get("user_id")
        except Exception:
            owner_id = None

    if user_id != actor_id and user_id != owner_id:
        raise HTTPException(
            status_code=403,
            detail="Only the commenter or story owner can delete this comment",
        )

    try:
        sb.table("story_comments").delete().eq("id", cid).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete comment: {e}")

    return {"deleted": True}


@router.get("/stories/{story_id}/comments")
async def list_story_comments(
    story_id: str, user_id: str = Depends(current_user_id)
):
    """List every comment on [story_id], oldest-first, joined with profiles.

    Any authenticated caller can read the thread — comments are open to all,
    mirroring the public-read RLS policy. Degrades to `[]` when the
    `story_comments` table hasn't been migrated yet.
    """
    sid = (story_id or "").strip()
    if not sid:
        raise HTTPException(status_code=400, detail="story_id is required")

    sb = get_supabase()

    # We don't 404 on a missing story — if the story has been deleted, the
    # comments cascade-deleted with it (FK ON DELETE CASCADE), so the list is
    # naturally empty. This keeps the read path resilient against feed/story
    # race conditions.

    try:
        res = (
            sb.table("story_comments")
            .select("id, actor_id, text, created_at")
            .eq("story_id", sid)
            .order("created_at", desc=False)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to empty so the sheet shows its
        # "be the first to comment" state instead of crashing.
        return []

    rows = res.data or []
    if not rows:
        return []

    profiles = _profile_map(sb, [r["actor_id"] for r in rows])
    return [
        {
            "id": r["id"],
            "actor": {
                "user_id": r["actor_id"],
                "display_name": profiles.get(r["actor_id"], {}).get("display_name"),
                "avatar_url": profiles.get(r["actor_id"], {}).get("avatar_url"),
            },
            "text": r.get("text") or "",
            "created_at": r.get("created_at"),
        }
        for r in rows
    ]
