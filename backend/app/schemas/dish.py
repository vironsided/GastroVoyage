from pydantic import BaseModel


class DishOut(BaseModel):
    id: int
    name: str
    slug: str
    cuisine: str
    country: str
    description: str
    image_url: str | None = None
    origin_lat: float
    origin_lng: float

    model_config = {"from_attributes": True}
