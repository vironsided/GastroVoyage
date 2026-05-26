from fastapi import APIRouter, Depends

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/map", tags=["map"])


@router.get("/countries")
async def map_countries(user_id: str = Depends(current_user_id)):
    sb = get_supabase()

    countries_res = (
        sb.table("countries")
        .select("id, name, flag_emoji, centroid_lat, centroid_lng, region, iso_a2")
        .execute()
    )
    # Get all visits with photo_path, ordered newest first
    visits_res = (
        sb.table("visits")
        .select("country_id, photo_path")
        .eq("user_id", user_id)
        .order("visited_on", desc=True)
        .execute()
    )

    # Map country_id -> first (latest) photo found
    visited_photos: dict[str, str | None] = {}
    for v in visits_res.data:
        cid = v["country_id"]
        if cid not in visited_photos:
            visited_photos[cid] = v.get("photo_path") or None

    return [
        {
            **c,
            "visited": c["id"] in visited_photos,
            "photo_url": visited_photos.get(c["id"]),
        }
        for c in countries_res.data
        if c.get("centroid_lat") and c.get("centroid_lng")
    ]
