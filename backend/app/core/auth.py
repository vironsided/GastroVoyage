"""JWT authentication dependency.

Every authenticated route must depend on `current_user_id` to extract and
validate the bearer token. The user_id is taken from the verified JWT,
never from request body or query parameters.
"""

from fastapi import Header, HTTPException, status

from app.core.supabase_client import get_supabase


async def current_user_id(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        sb = get_supabase()
        user_response = sb.auth.get_user(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user_response or not user_response.user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return str(user_response.user.id)
