from pydantic import BaseModel


class RestaurantOut(BaseModel):
    id: int
    name: str
    city: str
    address: str
    phone: str | None
    lat: float
    lng: float
    verified: bool

    model_config = {"from_attributes": True}
