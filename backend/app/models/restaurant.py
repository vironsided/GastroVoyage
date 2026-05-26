from sqlalchemy import Boolean, Float, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Restaurant(Base):
    __tablename__ = "restaurants"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(150), index=True)
    city: Mapped[str] = mapped_column(String(80), index=True, default="Baku")
    address: Mapped[str] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    lat: Mapped[float] = mapped_column(Float())
    lng: Mapped[float] = mapped_column(Float())
    verified: Mapped[bool] = mapped_column(Boolean(), default=False)
