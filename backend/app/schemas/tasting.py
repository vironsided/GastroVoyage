from datetime import datetime

from pydantic import BaseModel, Field


class TastingCreate(BaseModel):
    user_id: str = Field(min_length=2, max_length=100)
    dish_id: int
    restaurant_id: int
    rating: int | None = Field(default=None, ge=1, le=5)
    image_url: str | None = None


class TastingOut(BaseModel):
    id: int
    user_id: str
    dish_id: int
    restaurant_id: int
    rating: int | None
    tasted_at: datetime
    image_url: str | None = None
    moderation_status: str | None = None
