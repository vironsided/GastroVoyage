from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserTasting(Base):
    __tablename__ = "user_tastings"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(100), index=True)
    dish_id: Mapped[int] = mapped_column(ForeignKey("dishes.id"), index=True)
    restaurant_id: Mapped[int] = mapped_column(ForeignKey("restaurants.id"), index=True)
    rating: Mapped[int | None] = mapped_column(Integer(), nullable=True)
    tasted_at: Mapped[datetime] = mapped_column(DateTime(), default=datetime.utcnow)
