import re

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.supabase_client import get_supabase, get_auth_client

router = APIRouter(prefix="/auth", tags=["auth"])

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

_OAUTH_PROVIDERS = {"google", "apple"}


class SignUpRequest(BaseModel):
    email: str
    password: str
    display_name: str


class SignInRequest(BaseModel):
    email: str
    password: str


class ResendRequest(BaseModel):
    email: str


class RefreshRequest(BaseModel):
    refresh_token: str


class OAuthRequest(BaseModel):
    provider: str
    id_token: str
    access_token: str | None = None
    display_name: str | None = None


def _validate_signup(email: str, password: str, display_name: str) -> None:
    email = email.strip()
    if not _EMAIL_RE.match(email):
        raise HTTPException(422, "Invalid email address")
    if len(password) < 8:
        raise HTTPException(422, "Password must be at least 8 characters")
    if not display_name.strip():
        raise HTTPException(422, "Name is required")


@router.post("/signup")
async def signup(body: SignUpRequest):
    email = body.email.lower().strip()
    display_name = body.display_name.strip()

    _validate_signup(email, body.password, display_name)

    sb = get_auth_client()
    db = get_supabase()

    try:
        response = sb.auth.sign_up(
            {
                "email": email,
                "password": body.password,
                "options": {"data": {"display_name": display_name}},
            }
        )

        if response.user is None:
            raise HTTPException(400, "Registration failed. Please try again.")

        # Supabase silently returns a user with empty identities for duplicate emails
        identities = response.user.identities or []
        if len(identities) == 0:
            raise HTTPException(
                409, "An account with this email already exists. Please sign in."
            )

        user_id = str(response.user.id)
        email_confirmed = bool(response.user.email_confirmed_at)

        # Ensure profile row exists
        db.table("profiles").upsert(
            {"id": user_id, "display_name": display_name},
            on_conflict="id",
        ).execute()

        return {
            "user_id": user_id,
            "email": response.user.email,
            "display_name": display_name,
            "home_city": None,
            "access_token": response.session.access_token if response.session else None,
            "refresh_token": response.session.refresh_token if response.session else None,
            "email_confirmed": email_confirmed,
        }

    except HTTPException:
        raise
    except Exception as e:
        err = str(e).lower()
        if "already registered" in err or "already exists" in err:
            raise HTTPException(
                409, "An account with this email already exists. Please sign in."
            )
        if "weak" in err or ("password" in err and "short" in err):
            raise HTTPException(422, "Password is too weak. Use at least 8 characters.")
        raise HTTPException(400, "Registration failed. Please try again.")


@router.post("/signin")
async def signin(body: SignInRequest):
    email = body.email.lower().strip()
    sb = get_auth_client()
    db = get_supabase()

    try:
        response = sb.auth.sign_in_with_password(
            {"email": email, "password": body.password}
        )

        if response.user is None or response.session is None:
            raise HTTPException(401, "Invalid email or password")

        user_id = str(response.user.id)

        # Fetch profile
        profile_res = (
            db.table("profiles")
            .select("display_name, home_city")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        display_name = None
        home_city = None
        if profile_res.data:
            display_name = profile_res.data.get("display_name")
            home_city = profile_res.data.get("home_city")

        # Fall back to metadata or email prefix
        if not display_name and response.user.user_metadata:
            display_name = response.user.user_metadata.get("display_name")
        if not display_name:
            display_name = email.split("@")[0]

        return {
            "user_id": user_id,
            "email": response.user.email,
            "display_name": display_name,
            "home_city": home_city,
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "email_confirmed": bool(response.user.email_confirmed_at),
        }

    except HTTPException:
        raise
    except Exception as e:
        err = str(e).lower()
        if "email not confirmed" in err:
            raise HTTPException(
                403,
                "Please verify your email before signing in. Check your inbox.",
            )
        if "invalid login credentials" in err or "invalid" in err:
            raise HTTPException(401, "Invalid email or password")
        raise HTTPException(401, "Invalid email or password")


@router.post("/oauth")
async def oauth(body: OAuthRequest):
    """Exchange a native Google/Apple ID token for a Supabase session.

    The mobile app obtains the provider ID token via the native Google /
    Apple SDK, then POSTs it here. We hand it to Supabase, which verifies
    the token against the provider and issues its own session — so the
    mobile app only ever holds a GastroVoyage (Supabase) JWT, never a
    Google/Apple credential."""
    provider = body.provider.strip().lower()
    if provider not in _OAUTH_PROVIDERS:
        raise HTTPException(422, "Unsupported OAuth provider")

    id_token = body.id_token.strip()
    if not id_token:
        raise HTTPException(422, "Missing OAuth id_token")

    sb = get_auth_client()
    db = get_supabase()

    # gotrue's sign_in_with_id_token takes a TypedDict — pass a plain dict.
    credentials: dict = {"provider": provider, "token": id_token}
    if body.access_token and body.access_token.strip():
        credentials["access_token"] = body.access_token.strip()

    try:
        try:
            response = sb.auth.sign_in_with_id_token(credentials)
        except TypeError:
            # Older/newer signatures may not accept access_token — retry
            # without it rather than failing the whole sign-in.
            credentials.pop("access_token", None)
            response = sb.auth.sign_in_with_id_token(credentials)

        if response.user is None or response.session is None:
            raise HTTPException(401, f"Could not sign in with {provider}")

        user = response.user
        user_id = str(user.id)
        email = user.email or ""
        metadata = user.user_metadata or {}

        # Resolve a display name. Apple only sends the user's name on the
        # very first sign-in (carried in the request), so prefer that;
        # then provider metadata; then the email's local part.
        display_name = (body.display_name or "").strip()
        if not display_name:
            for key in ("full_name", "name", "display_name"):
                val = metadata.get(key)
                if val and str(val).strip():
                    display_name = str(val).strip()
                    break
        if not display_name:
            display_name = email.split("@")[0] if "@" in email else "Traveler"

        # Look for an existing profile so a returning OAuth user keeps the
        # name / home_city they previously set, and only upsert the name
        # when there isn't one yet (don't clobber a user-edited name).
        profile_res = (
            db.table("profiles")
            .select("display_name, home_city")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        existing_name = None
        home_city = None
        if profile_res and profile_res.data:
            existing_name = profile_res.data.get("display_name")
            home_city = profile_res.data.get("home_city")

        if existing_name and existing_name.strip():
            display_name = existing_name.strip()
        else:
            db.table("profiles").upsert(
                {"id": user_id, "display_name": display_name},
                on_conflict="id",
            ).execute()

        return {
            "user_id": user_id,
            "email": email,
            "display_name": display_name,
            "home_city": home_city,
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "email_confirmed": True,
        }

    except HTTPException:
        raise
    except Exception as e:
        err = str(e).lower()
        if "expired" in err:
            raise HTTPException(401, f"The {provider} sign-in token has expired. Please try again.")
        raise HTTPException(401, f"Could not sign in with {provider}")


@router.post("/refresh")
async def refresh(body: RefreshRequest):
    """Exchange a still-valid refresh token for a fresh access/refresh pair.
    The mobile client calls this automatically when an API call returns 401,
    so a user never gets logged out just because the ~1h access token aged out."""
    sb = get_auth_client()
    try:
        response = sb.auth.refresh_session(body.refresh_token)
        if response.session is None:
            raise HTTPException(401, "Session expired. Please sign in again.")
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
        }
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(401, "Session expired. Please sign in again.")


@router.post("/resend")
async def resend_verification(body: ResendRequest):
    email = body.email.lower().strip()
    sb = get_auth_client()
    try:
        sb.auth.resend({"type": "signup", "email": email})
    except Exception:
        pass  # never reveal whether the email exists
    return {"ok": True}
