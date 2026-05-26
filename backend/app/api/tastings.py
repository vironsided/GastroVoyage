from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.dish import Dish
from app.models.restaurant import Restaurant
from app.models.user_tasting import UserTasting
from app.models.user_tasting_photo import UserTastingPhoto
from app.schemas.tasting import TastingCreate

router = APIRouter(prefix="/tastings", tags=["tastings"])


@router.post("")
def create_tasting(payload: TastingCreate, db: Session = Depends(get_db)):
    dish_exists = db.query(Dish.id).filter(Dish.id == payload.dish_id).first()
    if not dish_exists:
        raise HTTPException(status_code=404, detail="Dish not found")
    restaurant_exists = db.query(Restaurant.id).filter(Restaurant.id == payload.restaurant_id).first()
    if not restaurant_exists:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    tasting = UserTasting(
        user_id=payload.user_id,
        dish_id=payload.dish_id,
        restaurant_id=payload.restaurant_id,
        rating=payload.rating,
    )
    db.add(tasting)
    db.flush()

    photo = None
    if payload.image_url:
        photo = UserTastingPhoto(
            tasting_id=tasting.id,
            image_url=payload.image_url,
            moderation_status="pending",
        )
        db.add(photo)

    db.commit()
    db.refresh(tasting)
    if photo:
        db.refresh(photo)

    return {
        "id": tasting.id,
        "user_id": tasting.user_id,
        "dish_id": tasting.dish_id,
        "restaurant_id": tasting.restaurant_id,
        "rating": tasting.rating,
        "tasted_at": tasting.tasted_at,
        "image_url": photo.image_url if photo else None,
        "moderation_status": photo.moderation_status if photo else None,
    }


@router.get("")
def list_tastings(user_id: str, db: Session = Depends(get_db)):
    tastings = (
        db.query(UserTasting, UserTastingPhoto)
        .outerjoin(UserTastingPhoto, UserTastingPhoto.tasting_id == UserTasting.id)
        .filter(UserTasting.user_id == user_id)
        .order_by(UserTasting.tasted_at.desc())
        .all()
    )
    return [
        {
            "id": tasting.id,
            "user_id": tasting.user_id or "",
            "dish_id": tasting.dish_id,
            "restaurant_id": tasting.restaurant_id,
            "rating": tasting.rating,
            "tasted_at": tasting.tasted_at,
            "image_url": photo.image_url if photo else None,
            "moderation_status": photo.moderation_status if photo else None,
        }
        for tasting, photo in tastings
    ]
