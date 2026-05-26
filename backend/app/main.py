from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    auth,
    profile,
    countries,
    visits,
    badges,
    map as map_api,
    uploads,
    social,
    couples,
    notifications,
    wishlist,
)
from app.core.config import settings

app = FastAPI(title=settings.app_name, version="2.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=None,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# All authenticated business routes are mounted under /v1 going forward.
# Keep /auth and /uploads at the root for now since auth precedes versioning
# and uploads will gain auth in this same change.
app.include_router(auth.router)
app.include_router(uploads.router)
app.include_router(profile.router)
app.include_router(countries.router)
app.include_router(visits.router)
app.include_router(badges.router)
app.include_router(map_api.router)
app.include_router(social.router)
app.include_router(couples.router)
app.include_router(notifications.router)
app.include_router(wishlist.router)


@app.get("/health")
def health():
    return {"status": "ok", "version": "2.1.0"}
