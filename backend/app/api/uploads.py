import uuid
import os

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException

from app.core.auth import current_user_id
from app.core.supabase_client import get_supabase

router = APIRouter(prefix="/uploads", tags=["uploads"])

BUCKET = "visit-photos"
MAX_BYTES = 8 * 1024 * 1024  # 8 MB
ALLOWED_CTYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


@router.post("")
async def upload_photo(
    file: UploadFile = File(...),
    user_id: str = Depends(current_user_id),
):
    if file.content_type and file.content_type not in ALLOWED_CTYPES:
        raise HTTPException(415, f"Unsupported file type: {file.content_type}")

    contents = await file.read()
    if len(contents) > MAX_BYTES:
        raise HTTPException(413, "File too large (max 8 MB)")

    sb = get_supabase()

    # Ensure bucket exists and is public
    try:
        sb.storage.create_bucket(BUCKET, options={"public": True})
    except Exception:
        pass  # already exists

    ext = os.path.splitext(file.filename or "photo.jpg")[1].lower() or ".jpg"
    # Scope each upload by user_id so abusive accounts can be wiped easily
    path = f"{user_id}/{uuid.uuid4()}{ext}"

    try:
        sb.storage.from_(BUCKET).upload(
            path,
            contents,
            {"content-type": file.content_type or "image/jpeg"},
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")

    url = sb.storage.from_(BUCKET).get_public_url(path)
    return {"url": url}
