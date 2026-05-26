from sqlalchemy import Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RestaurantDish(Base):
    __tablename__ = "restaurant_dishes"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    dish_id: Mapped[int] = mapped_column(ForeignKey("dishes.id"), index=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), index=True)
    confidence: Mapped[float] = mapped_column(Float(), default=0.7)
    price_range: Mapped[str] = mapped_column(default="$$")
