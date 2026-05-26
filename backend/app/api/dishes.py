from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.dish import Dish
from app.models.restaurant import Restaurant
from app.models.restaurant_dish import RestaurantDish
from app.schemas.dish import DishOut
from app.schemas.restaurant import RestaurantOut

router = APIRouter(prefix="/dishes", tags=["dishes"])


@router.get("", response_model=list[DishOut])
def list_dishes(
    q: str | None = Query(default=None),
    cuisine: str | None = Query(default=None),
    country: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> list[Dish]:
    query = db.query(Dish).filter(Dish.is_active.is_(True))
    if q:
        query = query.filter(Dish.name.ilike(f"%{q}%"))
    if cuisine:
        query = query.filter(Dish.cuisine == cuisine)
    if country:
        query = query.filter(Dish.country == country)
    return query.order_by(Dish.name.asc()).all()


@router.get("/{dish_id}", response_model=DishOut)
def get_dish(dish_id: int, db: Session = Depends(get_db)) -> Dish:
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(status_code=404, detail="Dish not found")
    return dish


@router.get("/{dish_id}/restaurants", response_model=list[RestaurantOut])
def list_restaurants_for_dish(dish_id: int, db: Session = Depends(get_db)) -> list[Restaurant]:
    exists = db.query(Dish.id).filter(Dish.id == dish_id).first()
    if not exists:
        raise HTTPException(status_code=404, detail="Dish not found")

    return (
        db.query(Restaurant)
        .join(RestaurantDish, RestaurantDish.restaurant_id == Restaurant.id)
        .filter(RestaurantDish.dish_id == dish_id)
        .order_by(Restaurant.verified.desc(), Restaurant.name.asc())
        .all()
    )
