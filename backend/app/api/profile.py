from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase, get_auth_client

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("/me")
async def get_profile(user_id: str = Depends(current_user_id)):
    sb = get_supabase()

    # select("*") so a DB that hasn't run migration 003 (no avatar_url column)
    # still returns a profile — the avatar simply comes back absent/null.
    profile_res = sb.table("profiles").select("*").eq("id", user_id).single().execute()

    visits_res = sb.table("visits").select("id, country_id").eq("user_id", user_id).execute()
    visited_country_ids = list({v["country_id"] for v in visits_res.data})

    user_badges_res = (
        sb.table("user_badges")
        .select("badge_code, earned_at, badges(title, icon)")
        .eq("user_id", user_id)
        .execute()
    )

    total_res = sb.table("countries").select("id", count="exact").execute()

    profile = profile_res.data or {}
    return {
        **profile,
        # Explicit so the mobile client always sees the key, even pre-migration.
        "avatar_url": profile.get("avatar_url"),
        "visited_count": len(visited_country_ids),
        "total_countries": total_res.count or 194,
        "badges": user_badges_res.data,
    }


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    home_city: Optional[str] = None
    avatar_url: Optional[str] = None


@router.patch("/me")
async def update_profile(
    body: ProfileUpdate,
    user_id: str = Depends(current_user_id),
):
    sb = get_supabase()
    update_data: dict = {}
    if body.display_name is not None:
        update_data["display_name"] = body.display_name
    if body.home_city is not None:
        update_data["home_city"] = body.home_city
    if body.avatar_url is not None:
        update_data["avatar_url"] = body.avatar_url
    if update_data:
        sb.table("profiles").update(update_data).eq("id", user_id).execute()
    return {"ok": True}


@router.delete("/me")
async def delete_account(user_id: str = Depends(current_user_id)):
    """Permanently delete the authenticated user and all their data.

    Destructive and irreversible. Order matters so a partial failure can
    never leave an orphaned auth user pointing at deleted data:
      1. visits          (child rows referencing the profile)
      2. user_badges     (child rows referencing the profile)
      3. follows         (both directions — edges referencing the profile)
      4. stories         (child rows referencing the profile)
      5. couples_journey (the couple's weekly-journey progress row)
      6. notifications   (both directions — addressed-to and actor)
      7. wishlist        (the user's "want to try" bookmarks)
      8. profiles        (the profile row itself)
      9. auth user       (last — once gone, the JWT can never authenticate again)
    """
    sb = get_supabase()

    try:
        sb.table("visits").delete().eq("user_id", user_id).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete visits: {e}")

    # Badges are best-effort: the table may not exist on every environment,
    # and a leftover badge row is harmless once the profile is gone.
    try:
        sb.table("user_badges").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    # Social rows are best-effort: the social tables may not exist on every
    # environment (migration 004), and leftover edges/stories are harmless
    # once the profile is gone. Delete follow edges in both directions so no
    # follower/following row is left pointing at a deleted user.
    try:
        sb.table("follows").delete().eq("follower_id", user_id).execute()
    except Exception:
        pass
    try:
        sb.table("follows").delete().eq("following_id", user_id).execute()
    except Exception:
        pass
    # The user's view records for OTHER people's stories aren't cascaded by
    # the stories→story_views FK (that cascade only fires when a story is
    # deleted), so clear them by viewer_id. Best-effort: the table may not
    # exist on every environment (migration 006).
    try:
        sb.table("story_views").delete().eq("viewer_id", user_id).execute()
    except Exception:
        pass
    try:
        sb.table("stories").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    # The couples'-journey row is best-effort: the table may not exist on
    # every environment (migration 005), and a leftover progress row is
    # harmless once the profile is gone.
    try:
        sb.table("couples_journey").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    # Notifications are best-effort: the table may not exist on every
    # environment (migration 007). Wipe both directions — rows addressed to
    # the user AND rows where they were the actor — so no notification is
    # left pointing at a deleted profile.
    try:
        sb.table("notifications").delete().eq("user_id", user_id).execute()
    except Exception:
        pass
    try:
        sb.table("notifications").delete().eq("actor_id", user_id).execute()
    except Exception:
        pass

    # Wishlist entries are best-effort: the table may not exist on every
    # environment (migration 010), and a leftover wishlist row is harmless
    # once the profile is gone.
    try:
        sb.table("wishlist").delete().eq("user_id", user_id).execute()
    except Exception:
        pass

    try:
        sb.table("profiles").delete().eq("id", user_id).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete profile: {e}")

    try:
        get_auth_client().auth.admin.delete_user(user_id)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Profile data removed but auth user could not be deleted: {e}",
        )

    return {"deleted": True}
