from pydantic import BaseModel, Field


class DishUpsert(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    slug: str = Field(min_length=2, max_length=150)
    cuisine: str = Field(min_length=2, max_length=80)
    country: str = Field(min_length=2, max_length=80)
    description: str = Field(min_length=10)
    origin_lat: float
    origin_lng: float
    is_active: bool = True


class RestaurantUpsert(BaseModel):
    name: str = Field(min_length=2, max_length=150)
    city: str = Field(default="Baku", min_length=2, max_length=80)
    address: str = Field(min_length=4, max_length=255)
    phone: str | None = Field(default=None, max_length=40)
    lat: float
    lng: float
    verified: bool = False


class RestaurantDishUpsert(BaseModel):
    dish_id: int
    restaurant_id: int
    confidence: float = Field(default=0.7, ge=0, le=1)
    price_range: str = Field(default="$$", max_length=10)


class PhotoModerationUpdate(BaseModel):
    moderation_status: str = Field(pattern="^(pending|approved|rejected)$")
