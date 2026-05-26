from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Challenge(Base):
    __tablename__ = "challenges"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    target_type: Mapped[str] = mapped_column(String(40))
    target_value: Mapped[str] = mapped_column(String(120))
    target_count: Mapped[int] = mapped_column(Integer(), default=10)
