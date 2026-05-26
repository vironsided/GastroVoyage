from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.dish import Dish
from app.models.restaurant import Restaurant
from app.models.restaurant_dish import RestaurantDish


def run():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if db.query(Dish).count() > 0:
            return

        dishes = [
            Dish(
                name="Levengi",
                slug="levengi",
                cuisine="Azerbaijani",
                country="Azerbaijan",
                description="Traditional walnut-onion stuffing served with fish or poultry.",
                image_url=None,
                origin_lat=38.7539,
                origin_lng=48.8506,
            ),
            Dish(
                name="Qutab",
                slug="qutab",
                cuisine="Azerbaijani",
                country="Azerbaijan",
                description="Thin pan-fried stuffed flatbread with meat, herbs, or pumpkin.",
                image_url=None,
                origin_lat=40.4093,
                origin_lng=49.8671,
            ),
            Dish(
                name="Guruli Khachapuri",
                slug="guruli-khachapuri",
                cuisine="Georgian",
                country="Georgia",
                description="Boat-like Georgian bread stuffed with cheese and egg variations.",
                image_url=None,
                origin_lat=42.3154,
                origin_lng=43.3569,
            ),
        ]
        db.add_all(dishes)
        db.flush()

        restaurants = [
            Restaurant(
                name="Shirvanshah Museum Restaurant",
                city="Baku",
                address="Salatin Asgarova St 86, Baku",
                phone="+994 12 493 33 05",
                lat=40.3821,
                lng=49.8295,
                verified=True,
            ),
            Restaurant(
                name="Nakhchivan Restaurant",
                city="Baku",
                address="Nizami St 93, Baku",
                phone="+994 12 599 11 22",
                lat=40.3746,
                lng=49.8384,
                verified=True,
            ),
            Restaurant(
                name="Tbilisi Corner Baku",
                city="Baku",
                address="Rashid Behbudov St 23, Baku",
                phone="+994 50 700 77 66",
                lat=40.3844,
                lng=49.8501,
                verified=False,
            ),
        ]
        db.add_all(restaurants)
        db.flush()

        links = [
            RestaurantDish(dish_id=dishes[0].id, restaurant_id=restaurants[0].id, confidence=0.9, price_range="$$"),
            RestaurantDish(dish_id=dishes[1].id, restaurant_id=restaurants[1].id, confidence=0.85, price_range="$"),
            RestaurantDish(dish_id=dishes[2].id, restaurant_id=restaurants[2].id, confidence=0.8, price_range="$$"),
        ]
        db.add_all(links)
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    run()
