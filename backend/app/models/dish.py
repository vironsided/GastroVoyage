from sqlalchemy import Boolean, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Dish(Base):
    __tablename__ = "dishes"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    slug: Mapped[str] = mapped_column(String(150), unique=True, index=True)
    cuisine: Mapped[str] = mapped_column(String(80), index=True)
    country: Mapped[str] = mapped_column(String(80), index=True)
    description: Mapped[str] = mapped_column(Text())
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    origin_lat: Mapped[float] = mapped_column(Float())
    origin_lng: Mapped[float] = mapped_column(Float())
    is_active: Mapped[bool] = mapped_column(Boolean(), default=True)
