from fastapi import APIRouter, Depends

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/badges", tags=["badges"])


@router.get("")
async def list_badges(user_id: str = Depends(current_user_id)):
    sb = get_supabase()

    all_res = sb.table("badges").select("*").order("sort_order").execute()
    earned_res = (
        sb.table("user_badges")
        .select("badge_code, earned_at")
        .eq("user_id", user_id)
        .execute()
    )
    earned = {b["badge_code"]: b["earned_at"] for b in earned_res.data}

    return [
        {**badge, "earned": badge["code"] in earned, "earned_at": earned.get(badge["code"])}
        for badge in all_res.data
    ]
