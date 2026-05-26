from fastapi import APIRouter, Depends, Query

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/countries", tags=["countries"])


@router.get("")
async def list_countries(
    user_id: str = Depends(current_user_id),
    region: str | None = Query(default=None),
    visited: bool | None = Query(default=None),
):
    sb = get_supabase()

    q = sb.table("countries").select("*").order("name")
    if region:
        q = q.eq("region", region)
    countries = q.execute()

    visits_res = sb.table("visits").select("country_id").eq("user_id", user_id).execute()
    visited_ids = {v["country_id"] for v in visits_res.data}

    result = []
    for c in countries.data:
        c["visited"] = c["id"] in visited_ids
        if visited is None or c["visited"] == visited:
            result.append(c)
    return result


@router.get("/regions")
async def list_regions():
    """Public — list of region names. No auth required."""
    sb = get_supabase()
    res = sb.table("countries").select("region").execute()
    regions = sorted({r["region"] for r in res.data if r.get("region")})
    return regions


@router.get("/{country_id}")
async def get_country(
    country_id: str,
    user_id: str = Depends(current_user_id),
):
    sb = get_supabase()

    country_res = sb.table("countries").select("*").eq("id", country_id).single().execute()
    visits_res = (
        sb.table("visits")
        .select("*")
        .eq("user_id", user_id)
        .eq("country_id", country_id)
        .order("visited_on", desc=True)
        .execute()
    )

    return {
        **country_res.data,
        "visits": visits_res.data,
        "visited": len(visits_res.data) > 0,
    }
