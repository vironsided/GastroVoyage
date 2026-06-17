"""AI-powered endpoints — Gemini (free tier) backed.

Four features, each under `/ai/...`:

  1. GET  /ai/date-night            — couples-only, generates a specific
                                       dish + 5-step prep outline + reason
                                       for a Date Night, picking a country
                                       from the couple's joint wishlists.
  2. GET  /ai/cuisine-recommendations — analyzes the viewer's recent
                                         visits and recommends 3 new
                                         cuisines to try.
  3. POST /ai/parse-visit-photo     — Gemini vision parses an uploaded
                                       photo into {dish, country guess,
                                       suggested ratings, notes} so the
                                       user can pre-fill the visit form.

The fourth (Couple Wrapped) lives in `couples.py` so it sits alongside
the other couple endpoints.

Every endpoint:
  • Authenticates via Depends(current_user_id) — no user_id from body.
  • Returns 503 (not 500) when GEMINI_API_KEY is missing.
  • Goes through `ai_generate_structured()`, which returns a validated
    Pydantic instance for any response Mobile needs to render structurally.
"""

import random
from typing import Literal

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from app.api.couples import _fetch_active_couple
from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase
from app.services.ai_client import ai_generate_structured

router = APIRouter(prefix="/ai", tags=["ai"])


# ─── Response schemas (also used as Pydantic models for structured outputs) ─

class DateNightSuggestion(BaseModel):
    """Structured payload Mobile renders as a Date Night card."""
    country_name: str = Field(description="Country whose cuisine to cook tonight")
    flag_emoji: str | None = Field(default=None, description="Flag emoji of the country")
    dish_name: str = Field(description="Specific dish to make — e.g. 'Khinkali', 'Pad See Ew'")
    cuisine: str | None = Field(default=None, description="Short cuisine label, e.g. 'Georgian'")
    headline: str = Field(description="One-line warm tagline addressed to the couple")
    why_tonight: str = Field(description="2-3 sentence reason this dish fits their journey tonight")
    prep_steps: list[str] = Field(
        description="5 short imperative prep steps (each <= 18 words)",
        min_length=3,
        max_length=7,
    )


class CuisineRecommendation(BaseModel):
    country_name: str
    flag_emoji: str | None = None
    cuisine: str | None = None
    reasoning: str = Field(description="Why this user should try it, max 2 sentences")
    signature_dish: str = Field(description="One iconic dish to start with")


class CuisineRecommendations(BaseModel):
    """Three handpicked cuisines the viewer hasn't tasted yet."""
    items: list[CuisineRecommendation] = Field(min_length=1, max_length=3)


class VisitPhotoParse(BaseModel):
    """What Claude vision extracted from an uploaded restaurant photo.

    Every field is best-effort — null when the model can't tell from the
    image. Mobile uses these to pre-fill the visit form; the user always
    confirms before save.
    """
    dish_name: str | None = Field(default=None, description="What dish appears in the photo")
    likely_country_name: str | None = Field(
        default=None,
        description="Which cuisine/country this dish most likely belongs to",
    )
    cuisine: str | None = None
    restaurant_visible_text: str | None = Field(
        default=None,
        description="Any restaurant name/menu text actually visible in the image, or null",
    )
    confidence: Literal["low", "medium", "high"] = Field(
        description="How confident the dish ID is — 'low' when the image is dim or ambiguous"
    )
    suggested_dish_rating: int | None = Field(default=None, ge=1, le=5)
    suggested_atmosphere_rating: int | None = Field(default=None, ge=1, le=5)
    suggested_notes: str | None = Field(
        default=None,
        description="A short, warm one-line journal note the user can keep or edit",
    )


# ─── 1. Couple Date Night picker ────────────────────────────────────────────

@router.get("/date-night", response_model=DateNightSuggestion)
async def ai_date_night(user_id: str = Depends(current_user_id)):
    """Returns a specific dish + prep outline for the couple to make tonight.

    Pulls candidate countries the same way `/couples/date-night` does
    (combined wishlist of both partners, excluding ones they've already
    tasted together), then asks Claude to turn one of them into a
    Date Night card.

    Fails with 409 if the viewer has no active couple — this is a
    couples-only feature.
    """
    sb = get_supabase()
    couple = _fetch_active_couple(sb, user_id)
    if not couple or couple["status"] != "accepted":
        raise HTTPException(409, "No active couple — link a partner first.")

    partner_id = (
        couple["partner_b_id"]
        if couple["partner_a_id"] == user_id
        else couple["partner_a_id"]
    )

    # ── Reuse the wishlist/joint-visit candidate logic ──────────────────────
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

    candidates = list(wished - already_joint)
    if not candidates:
        # Fall back to anything not yet jointly tasted.
        try:
            cres = sb.table("countries").select("id").execute()
            candidates = [
                r["id"] for r in (cres.data or [])
                if r.get("id") and r["id"] not in already_joint
            ]
        except Exception:
            candidates = []

    if not candidates:
        raise HTTPException(
            404, "No country left to suggest — you've tasted everything together."
        )

    pick_id = random.choice(candidates)
    try:
        country_row = (
            sb.table("countries")
            .select("id, name, flag_emoji, region, subregion")
            .eq("id", pick_id)
            .maybe_single()
            .execute()
        )
        country = (country_row.data if country_row else None) or {}
    except Exception:
        country = {}

    if not country.get("name"):
        raise HTTPException(500, "Could not load country details.")

    # ── Past 5 joint visits as flavor context ──────────────────────────────
    recent_summary = _recent_joint_summary(sb, user_id, partner_id, limit=5)

    # ── Ask Gemini for a Date Night card ───────────────────────────────────
    pick = ai_generate_structured(
        system=(
            "You are the kitchen sidekick for a couple using GastroVoyage, "
            "a scrapbook-style culinary passport app. Your tone is warm, "
            "lightly poetic, and addresses both partners as 'you two'. "
            "Never use emoji in body text (only flag_emoji field). "
            "Steps must be doable at home in under 90 minutes with a "
            "standard kitchen — assume the couple isn't a chef."
        ),
        user_text=(
            f"Cuisine to feature tonight: {country['name']} "
            f"({country.get('flag_emoji') or ''}). "
            f"Subregion: {country.get('subregion') or country.get('region') or 'unknown'}.\n\n"
            f"Recent joint plates the couple has shared:\n{recent_summary}\n\n"
            "Pick ONE specific dish from this cuisine that fits a "
            "Date Night cook at home. Write a Date Night card."
        ),
        schema=DateNightSuggestion,
        max_tokens=2000,
    )
    # Always trust our country data over the model's echo — keeps flag/name
    # consistent with the DB even if Claude slightly varies the spelling.
    pick.country_name = country["name"]
    if country.get("flag_emoji"):
        pick.flag_emoji = country["flag_emoji"]
    return pick


# ─── 2. Smart cuisine recommendations ───────────────────────────────────────

@router.get("/cuisine-recommendations", response_model=CuisineRecommendations)
async def ai_cuisine_recommendations(user_id: str = Depends(current_user_id)):
    """Three cuisines Claude thinks the viewer should try next.

    Excludes countries already tasted. Uses sub-ratings (atmosphere /
    dish / value / service) when available to infer the viewer's taste,
    so the recommendation isn't just "anywhere new".
    """
    sb = get_supabase()

    # Past visits — most recent first, capped to 20 so the prompt stays small.
    tasted_ids: set[str] = set()
    history_lines: list[str] = []
    try:
        vres = (
            sb.table("visits")
            .select(
                "country_id, rating, atmosphere_rating, dish_rating, "
                "value_rating, service_rating, notes, restaurant_name, "
                "countries(name, region, subregion, flag_emoji)"
            )
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        )
        for r in vres.data or []:
            cid = r.get("country_id")
            if cid:
                tasted_ids.add(cid)
            c = r.get("countries") or {}
            name = c.get("name") or "?"
            sub = c.get("subregion") or c.get("region") or "?"
            rating = r.get("rating") or 0
            dish = (r.get("notes") or "").strip()[:60]
            history_lines.append(
                f"  - {name} ({sub}) · {rating}/5"
                + (f" · note: {dish}" if dish else "")
            )
    except Exception:
        pass

    if not history_lines:
        raise HTTPException(
            409, "Log a few visits first — there's nothing to recommend from yet."
        )

    # Untasted pool — give Claude only names + region so the prompt stays compact.
    untasted_pool: list[dict] = []
    try:
        cres = (
            sb.table("countries")
            .select("id, name, region, subregion, flag_emoji")
            .execute()
        )
        for r in cres.data or []:
            if r.get("id") and r["id"] not in tasted_ids:
                untasted_pool.append(r)
    except Exception:
        pass

    if not untasted_pool:
        raise HTTPException(
            404, "You've tasted every country on the map — astonishing."
        )

    # Cap to 80 untasted candidates randomly. Keeps the prompt fast on users
    # who have only tasted 1-2 countries and have ~190 in the untasted pool.
    sample = random.sample(untasted_pool, min(80, len(untasted_pool)))
    untasted_summary = "\n".join(
        f"  - {c['name']} ({c.get('subregion') or c.get('region') or '?'})"
        for c in sample
    )

    recs = ai_generate_structured(
        system=(
            "You recommend cuisines to a GastroVoyage user based on their "
            "taste history. Pick exactly 3 cuisines from the untasted "
            "list that complement what they've enjoyed. Each reasoning "
            "must reference a specific past visit. Tone: warm, "
            "scrapbook-paper, lightly poetic. No emoji in body text."
        ),
        user_text=(
            f"Past visits (newest first):\n{'\n'.join(history_lines)}\n\n"
            f"Untasted countries to choose from:\n{untasted_summary}\n\n"
            "Recommend 3 cuisines this person should try next."
        ),
        schema=CuisineRecommendations,
        max_tokens=2000,
    )

    # Backfill flag emojis from our DB when the model doesn't have them.
    by_name = {c["name"].lower(): c for c in untasted_pool}
    for item in recs.items:
        if not item.flag_emoji:
            row = by_name.get(item.country_name.lower())
            if row and row.get("flag_emoji"):
                item.flag_emoji = row["flag_emoji"]
    return recs


# ─── 3. Photo → pre-filled visit ────────────────────────────────────────────

# Accepted by Gemini vision: JPEG/PNG/GIF/WebP. Anything else → 415.
_VISION_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/gif",
    "image/webp",
}
_MAX_PHOTO_BYTES = 8 * 1024 * 1024  # 8 MB — comfortable headroom under Gemini's limit


@router.post("/parse-visit-photo", response_model=VisitPhotoParse)
async def ai_parse_visit_photo(
    file: UploadFile = File(...),
    user_id: str = Depends(current_user_id),
):
    """Take a restaurant/dish photo and pre-fill a visit-form suggestion.

    Mobile sends the raw bytes; we forward them to Gemini vision.
    The response is best-effort — Mobile shows fields as suggestions
    the user can override before saving the visit.
    """
    mime = (file.content_type or "").lower()
    if mime not in _VISION_MIME_TYPES:
        raise HTTPException(
            415, f"Unsupported image type '{mime}'. Send JPEG, PNG, GIF, or WebP."
        )

    data = await file.read()
    if not data:
        raise HTTPException(400, "Empty image upload.")
    if len(data) > _MAX_PHOTO_BYTES:
        raise HTTPException(
            413, "Image too large — please send under 8 MB."
        )
    return ai_generate_structured(
        system=(
            "You are a food identification assistant for GastroVoyage. "
            "Look at the photo and identify the dish, the most likely "
            "cuisine/country, and (only if visible) any restaurant text. "
            "Suggest ratings ONLY if there's a strong visual signal — "
            "leave them null when unsure. Never fabricate restaurant names. "
            "Notes should be a warm 1-line journal entry."
        ),
        user_text=(
            "Identify this food. What dish is it, most likely "
            "from which cuisine? If any restaurant signage or "
            "menu text is visible, include it verbatim. "
            "Otherwise leave restaurant_visible_text null."
        ),
        schema=VisitPhotoParse,
        max_tokens=1500,
        image=(mime, data),
    )


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _recent_joint_summary(sb, user_a: str, user_b: str, limit: int = 5) -> str:
    """Newline-separated short summary of recent joint visits. Returns a
    placeholder string when the couple hasn't logged any joint visits yet
    — useful as flavor context in the date-night prompt.
    """
    try:
        res = (
            sb.table("visits")
            .select(
                "rating, notes, restaurant_name, "
                "countries(name, subregion, region)"
            )
            .in_("user_id", [user_a, user_b])
            .eq("with_partner", True)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
    except Exception:
        return "  (no joint visits yet — this is their first attempt)"

    rows = res.data or []
    if not rows:
        return "  (no joint visits yet — this is their first attempt)"

    out: list[str] = []
    for r in rows:
        c = r.get("countries") or {}
        name = c.get("name") or "?"
        sub = c.get("subregion") or c.get("region") or "?"
        rating = r.get("rating") or 0
        out.append(f"  - {name} ({sub}) · {rating}/5")
    return "\n".join(out)
