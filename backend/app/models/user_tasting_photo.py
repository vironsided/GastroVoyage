from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserTastingPhoto(Base):
    __tablename__ = "user_tasting_photos"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    tasting_id: Mapped[int] = mapped_column(ForeignKey("user_tastings.id"), index=True)
    image_url: Mapped[str] = mapped_column(String(500))
    moderation_status: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(), default=datetime.utcnow)
