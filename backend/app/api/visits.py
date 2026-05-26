from fastapi import APIRouter, Body, Depends, Query, HTTPException

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/visits", tags=["visits"])


@router.get("")
async def list_visits(
    user_id: str = Depends(current_user_id),
    limit: int = Query(default=50),
):
    sb = get_supabase()
    res = (
        sb.table("visits")
        .select("*, countries(id, name, flag_emoji, region, iso_a2, centroid_lat, centroid_lng)")
        .eq("user_id", user_id)
        .order("visited_on", desc=True)
        .limit(limit)
        .execute()
    )
    return res.data


def _clamp_subrating(v: int | None) -> int | None:
    """Coerce a 1–5 sub-rating, allowing None to mean "not rated"."""
    if v is None:
        return None
    return max(1, min(5, int(v)))


@router.post("")
async def create_visit(
    country_id: str = Body(...),
    visited_on: str = Body(...),
    notes: str = Body(default=""),
    rating: int = Body(default=5),
    photo_path: str | None = Body(default=None),
    restaurant_name: str | None = Body(default=None),
    atmosphere_rating: int | None = Body(default=None),
    service_rating: int | None = Body(default=None),
    value_rating: int | None = Body(default=None),
    dish_rating: int | None = Body(default=None),
    with_partner: bool | None = Body(default=None),
    user_id: str = Depends(current_user_id),
):
    sb = get_supabase()

    row: dict = {
        "user_id": user_id,
        "country_id": country_id,
        "notes": notes,
        "rating": max(1, min(5, rating)),
        "visited_on": visited_on,
    }
    if photo_path:
        row["photo_path"] = photo_path
    # Only include restaurant_name when set, so the insert still succeeds on a
    # DB where migration 002_visit_restaurant.sql has not yet been run.
    if restaurant_name:
        row["restaurant_name"] = restaurant_name
    # Sub-ratings — silently dropped if migration 013 hasn't been applied yet
    # (Supabase rejects unknown columns, so we only set them when non-null).
    for key, value in {
        "atmosphere_rating": _clamp_subrating(atmosphere_rating),
        "service_rating": _clamp_subrating(service_rating),
        "value_rating": _clamp_subrating(value_rating),
        "dish_rating": _clamp_subrating(dish_rating),
    }.items():
        if value is not None:
            row[key] = value

    # with_partner — migration 015. Same defensive retry pattern.
    if with_partner is not None:
        row["with_partner"] = bool(with_partner)

    try:
        res = sb.table("visits").insert(row).execute()
    except Exception as e:
        # If the schema cache rejects the new columns (migrations 013/015 not
        # run), retry without them so the legacy flow still works.
        msg = str(e).lower()
        optional_cols = (
            "atmosphere_rating",
            "service_rating",
            "value_rating",
            "dish_rating",
            "with_partner",
        )
        if any(k in msg for k in optional_cols):
            for k in optional_cols:
                row.pop(k, None)
            res = sb.table("visits").insert(row).execute()
        else:
            raise

    _award_badges(user_id, sb)
    return res.data[0]


@router.patch("/{visit_id}")
async def update_visit(
    visit_id: str,
    notes: str | None = Body(default=None),
    rating: int | None = Body(default=None),
    visited_on: str | None = Body(default=None),
    photo_path: str | None = Body(default=None),
    restaurant_name: str | None = Body(default=None),
    atmosphere_rating: int | None = Body(default=None),
    service_rating: int | None = Body(default=None),
    value_rating: int | None = Body(default=None),
    dish_rating: int | None = Body(default=None),
    with_partner: bool | None = Body(default=None),
    user_id: str = Depends(current_user_id),
):
    sb = get_supabase()

    existing = (
        sb.table("visits")
        .select("id")
        .eq("id", visit_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Visit not found")

    updates: dict = {}
    if notes is not None:
        updates["notes"] = notes
    if rating is not None:
        updates["rating"] = max(1, min(5, rating))
    if visited_on is not None:
        updates["visited_on"] = visited_on
    if photo_path is not None:
        updates["photo_path"] = photo_path
    # Only include restaurant_name when set, so the update still succeeds on a
    # DB where migration 002_visit_restaurant.sql has not yet been run.
    if restaurant_name is not None:
        updates["restaurant_name"] = restaurant_name
    # Sub-ratings — same pattern as create_visit. The PATCH treats null as "no
    # change", so the caller has to use 0 (which we clamp to 1) to actually
    # downgrade. In practice the form always sends concrete 1–5 values.
    for key, value in {
        "atmosphere_rating": _clamp_subrating(atmosphere_rating),
        "service_rating": _clamp_subrating(service_rating),
        "value_rating": _clamp_subrating(value_rating),
        "dish_rating": _clamp_subrating(dish_rating),
    }.items():
        if value is not None:
            updates[key] = value

    # with_partner flag — migration 015. Retried-without on schema miss.
    if with_partner is not None:
        updates["with_partner"] = bool(with_partner)

    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    try:
        res = (
            sb.table("visits")
            .update(updates)
            .eq("id", visit_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as e:
        msg = str(e).lower()
        optional_cols = (
            "atmosphere_rating",
            "service_rating",
            "value_rating",
            "dish_rating",
            "with_partner",
        )
        if any(k in msg for k in optional_cols):
            for k in optional_cols:
                updates.pop(k, None)
            if not updates:
                raise HTTPException(status_code=400, detail="No fields to update")
            res = (
                sb.table("visits")
                .update(updates)
                .eq("id", visit_id)
                .eq("user_id", user_id)
                .execute()
            )
        else:
            raise
    return res.data[0]


@router.delete("/{visit_id}")
async def delete_visit(
    visit_id: str,
    user_id: str = Depends(current_user_id),
):
    sb = get_supabase()
    res = sb.table("visits").delete().eq("id", visit_id).eq("user_id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Visit not found")
    return {"deleted": True}


def _award_badges(user_id: str, sb) -> None:
    visits_res = (
        sb.table("visits")
        .select("country_id, countries(region)")
        .eq("user_id", user_id)
        .execute()
    )
    total = len(visits_res.data)
    region_counts: dict[str, int] = {}
    for v in visits_res.data:
        region = (v.get("countries") or {}).get("region", "")
        if region:
            region_counts[region] = region_counts.get(region, 0) + 1

    existing = {
        b["badge_code"]
        for b in sb.table("user_badges").select("badge_code").eq("user_id", user_id).execute().data
    }

    to_award: list[str] = []
    if total >= 1 and "first_steps" not in existing:
        to_award.append("first_steps")
    if total >= 100 and "half_world" not in existing:
        to_award.append("half_world")
    if total >= 195 and "world_traveler" not in existing:
        to_award.append("world_traveler")

    region_rules = {
        "Asia": ("asian_explorer", 10),
        "Europe": ("european_voyager", 10),
        "Africa": ("african_pioneer", 10),
        "Americas": ("american_trailblazer", 10),
        "Oceania": ("oceania_sailor", 5),
    }
    for region, (code, threshold) in region_rules.items():
        if region_counts.get(region, 0) >= threshold and code not in existing:
            to_award.append(code)

    for code in to_award:
        try:
            sb.table("user_badges").insert({"user_id": user_id, "badge_code": code}).execute()
        except Exception:
            pass
