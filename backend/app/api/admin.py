from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.dish import Dish
from app.models.restaurant import Restaurant
from app.models.restaurant_dish import RestaurantDish
from app.models.user_tasting import UserTasting
from app.models.user_tasting_photo import UserTastingPhoto
from app.schemas.admin import DishUpsert, PhotoModerationUpdate, RestaurantDishUpsert, RestaurantUpsert

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/summary")
def summary(db: Session = Depends(get_db)):
    return {
        "dishes": db.query(Dish).count(),
        "restaurants": db.query(Restaurant).count(),
        "restaurant_dishes": db.query(RestaurantDish).count(),
        "pending_photos": db.query(UserTastingPhoto)
        .filter(UserTastingPhoto.moderation_status == "pending")
        .count(),
    }


@router.get("/dishes")
def admin_list_dishes(
    q: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(Dish)
    if q:
        query = query.filter(Dish.name.ilike(f"%{q}%"))
    return query.order_by(Dish.name.asc()).all()


@router.post("/dishes")
def admin_create_dish(payload: DishUpsert, db: Session = Depends(get_db)):
    exists = db.query(Dish.id).filter((Dish.slug == payload.slug) | (Dish.name == payload.name)).first()
    if exists:
        raise HTTPException(status_code=409, detail="Dish already exists")
    dish = Dish(**payload.model_dump())
    db.add(dish)
    db.commit()
    db.refresh(dish)
    return dish


@router.put("/dishes/{dish_id}")
def admin_update_dish(dish_id: int, payload: DishUpsert, db: Session = Depends(get_db)):
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(status_code=404, detail="Dish not found")
    for key, value in payload.model_dump().items():
        setattr(dish, key, value)
    db.commit()
    db.refresh(dish)
    return dish


@router.delete("/dishes/{dish_id}")
def admin_delete_dish(dish_id: int, db: Session = Depends(get_db)):
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(status_code=404, detail="Dish not found")
    db.delete(dish)
    db.commit()
    return {"deleted": True}


@router.get("/restaurants")
def admin_list_restaurants(
    q: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(Restaurant)
    if q:
        query = query.filter(Restaurant.name.ilike(f"%{q}%"))
    return query.order_by(Restaurant.verified.desc(), Restaurant.name.asc()).all()


@router.post("/restaurants")
def admin_create_restaurant(payload: RestaurantUpsert, db: Session = Depends(get_db)):
    restaurant = Restaurant(**payload.model_dump())
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.put("/restaurants/{restaurant_id}")
def admin_update_restaurant(restaurant_id: int, payload: RestaurantUpsert, db: Session = Depends(get_db)):
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    for key, value in payload.model_dump().items():
        setattr(restaurant, key, value)
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.delete("/restaurants/{restaurant_id}")
def admin_delete_restaurant(restaurant_id: int, db: Session = Depends(get_db)):
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    db.delete(restaurant)
    db.commit()
    return {"deleted": True}


@router.get("/restaurant-dishes")
def admin_list_restaurant_dishes(db: Session = Depends(get_db)):
    return db.query(RestaurantDish).all()


@router.post("/restaurant-dishes")
def admin_create_restaurant_dish(payload: RestaurantDishUpsert, db: Session = Depends(get_db)):
    relation = (
        db.query(RestaurantDish)
        .filter(
            RestaurantDish.dish_id == payload.dish_id,
            RestaurantDish.restaurant_id == payload.restaurant_id,
        )
        .first()
    )
    if relation:
        raise HTTPException(status_code=409, detail="Relation already exists")
    relation = RestaurantDish(**payload.model_dump())
    db.add(relation)
    db.commit()
    db.refresh(relation)
    return relation


@router.put("/restaurant-dishes/{relation_id}")
def admin_update_restaurant_dish(relation_id: int, payload: RestaurantDishUpsert, db: Session = Depends(get_db)):
    relation = db.query(RestaurantDish).filter(RestaurantDish.id == relation_id).first()
    if not relation:
        raise HTTPException(status_code=404, detail="Relation not found")
    for key, value in payload.model_dump().items():
        setattr(relation, key, value)
    db.commit()
    db.refresh(relation)
    return relation


@router.delete("/restaurant-dishes/{relation_id}")
def admin_delete_restaurant_dish(relation_id: int, db: Session = Depends(get_db)):
    relation = db.query(RestaurantDish).filter(RestaurantDish.id == relation_id).first()
    if not relation:
        raise HTTPException(status_code=404, detail="Relation not found")
    db.delete(relation)
    db.commit()
    return {"deleted": True}


@router.get("/photos/pending")
def admin_pending_photos(db: Session = Depends(get_db)):
    photos = (
        db.query(UserTastingPhoto, UserTasting)
        .join(UserTasting, UserTasting.id == UserTastingPhoto.tasting_id)
        .filter(UserTastingPhoto.moderation_status == "pending")
        .order_by(UserTastingPhoto.created_at.asc())
        .all()
    )
    return [
        {
            "photo_id": photo.id,
            "tasting_id": tasting.id,
            "user_id": tasting.user_id,
            "dish_id": tasting.dish_id,
            "restaurant_id": tasting.restaurant_id,
            "image_url": photo.image_url,
            "moderation_status": photo.moderation_status,
            "created_at": photo.created_at,
        }
        for photo, tasting in photos
    ]


@router.patch("/photos/{photo_id}")
def admin_moderate_photo(photo_id: int, payload: PhotoModerationUpdate, db: Session = Depends(get_db)):
    photo = db.query(UserTastingPhoto).filter(UserTastingPhoto.id == photo_id).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    photo.moderation_status = payload.moderation_status
    db.commit()
    db.refresh(photo)
    return photo
