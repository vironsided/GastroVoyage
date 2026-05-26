"""Wishlist ("Want to try") API — the bucket list of countries a user wants
to taste their way through.

Every endpoint authenticates via `current_user_id` (the verified Bearer JWT).
The user_id is never read from the request body or query string.

Requires migration `010_wishlist.sql` (the `wishlist` table). Reads degrade
to an empty list when the table hasn't been migrated yet so a fresh DB still
boots the mobile app without 500-ing the wishlist tabs.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/wishlist", tags=["wishlist"])


# ── helpers ──────────────────────────────────────────────────────────────────
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


# ── endpoints ────────────────────────────────────────────────────────────────
@router.get("")
async def list_wishlist(user_id: str = Depends(current_user_id)):
    """Newest-first wishlist for the authenticated user.

    Returns `[{country: {id, name, iso_a2, flag_emoji, region}, created_at}]`.
    Degrades to `[]` when the `wishlist` table hasn't been migrated yet.
    """
    sb = get_supabase()
    try:
        rows_res = (
            sb.table("wishlist")
            .select("country_id, created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception:
        # Table not migrated yet — degrade to an empty wishlist rather than
        # 500-ing the Explore / Dashboard surfaces that read it on boot.
        return []

    rows = rows_res.data or []
    if not rows:
        return []

    countries = _country_map(sb, [r["country_id"] for r in rows])
    out: list[dict] = []
    for r in rows:
        country = countries.get(r["country_id"])
        if not country:
            # The wishlist row points at a country that was removed from the
            # catalog — skip it rather than surface a half-blank card.
            continue
        out.append(
            {
                "country": {
                    "id": country.get("id"),
                    "name": country.get("name"),
                    "iso_a2": country.get("iso_a2"),
                    "flag_emoji": country.get("flag_emoji"),
                    "region": country.get("region"),
                },
                "created_at": r.get("created_at"),
            }
        )
    return out


class WishlistAdd(BaseModel):
    country_id: str


@router.post("")
async def add_to_wishlist(
    body: WishlistAdd,
    user_id: str = Depends(current_user_id),
):
    """Add a country to the caller's wishlist (idempotent on user × country).

    404 when the country doesn't exist in the catalog. Re-adding an existing
    pair is a no-op success — the mobile client can fire the call optimistically
    on a double-tap without seeing a spurious error.
    """
    country_id = (body.country_id or "").strip()
    if not country_id:
        raise HTTPException(status_code=400, detail="country_id is required")

    sb = get_supabase()

    # Validate the country exists so we never persist dangling references.
    country_res = (
        sb.table("countries").select("id").eq("id", country_id).execute()
    )
    if not country_res.data:
        raise HTTPException(status_code=404, detail="Country not found")

    existing = (
        sb.table("wishlist")
        .select("id")
        .eq("user_id", user_id)
        .eq("country_id", country_id)
        .execute()
    )
    if existing.data:
        # Already on the wishlist — idempotent success.
        return {"added": True}

    try:
        sb.table("wishlist").insert(
            {"user_id": user_id, "country_id": country_id}
        ).execute()
    except Exception:
        # Lost an insert race against the unique constraint — re-check and
        # report success if the winning row is ours.
        again = (
            sb.table("wishlist")
            .select("id")
            .eq("user_id", user_id)
            .eq("country_id", country_id)
            .execute()
        )
        if again.data:
            return {"added": True}
        raise HTTPException(status_code=500, detail="Failed to add to wishlist")

    return {"added": True}


@router.delete("/{country_id}")
async def remove_from_wishlist(
    country_id: str,
    user_id: str = Depends(current_user_id),
):
    """Remove a country from the caller's wishlist. Idempotent — calling on a
    pair that isn't on the list still returns success so the mobile UI's
    optimistic pin-toggle stays in sync.
    """
    cid = (country_id or "").strip()
    if not cid:
        raise HTTPException(status_code=400, detail="country_id is required")

    sb = get_supabase()
    try:
        sb.table("wishlist").delete().eq("user_id", user_id).eq(
            "country_id", cid
        ).execute()
    except Exception:
        # Table not migrated yet — there's nothing to delete, so the user's
        # optimistic state is already correct. Report success.
        return {"deleted": True}
    return {"deleted": True}
