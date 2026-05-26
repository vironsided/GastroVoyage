from __future__ import annotations

import re
from typing import Optional

import requests
from bs4 import BeautifulSoup

from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.dish import Dish


def _extract_best_image_url(html: str) -> Optional[str]:
    soup = BeautifulSoup(html, "html.parser")

    for selector in [
        ('meta[property="og:image"]', "content"),
        ('meta[name="twitter:image"]', "content"),
    ]:
        tag = soup.select_one(selector[0])
        if tag and tag.get(selector[1]):
            return tag.get(selector[1]).strip()

    # Fallback: first large-ish image
    for img in soup.select("img[src]"):
        src = (img.get("src") or "").strip()
        if src.startswith("http"):
            if re.search(r"\.(jpg|jpeg|png|webp)($|\?)", src, re.IGNORECASE):
                return src
    return None


def sync_images():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        dishes = db.query(Dish).order_by(Dish.id.asc()).all()
        updated = 0
        for dish in dishes:
            url = f"https://www.tasteatlas.com/{dish.slug}"
            try:
                response = requests.get(
                    url,
                    timeout=15,
                    headers={"User-Agent": "GastroVoyageBot/1.0"},
                )
                if response.status_code != 200:
                    continue
                image_url = _extract_best_image_url(response.text)
                if image_url and dish.image_url != image_url:
                    dish.image_url = image_url
                    updated += 1
            except requests.RequestException:
                continue

        db.commit()
        print(f"tasteatlas image sync complete, updated={updated}")
    finally:
        db.close()


if __name__ == "__main__":
    sync_images()
