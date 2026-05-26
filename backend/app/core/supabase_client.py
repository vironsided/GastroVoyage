from supabase import create_client, Client
from app.core.config import settings

_db_client: Client | None = None


def get_supabase() -> Client:
    """Singleton admin client for database operations only.
    Never call auth.sign_in / sign_up on this client — it would store a
    short-lived user JWT and break all subsequent DB calls after ~1 hour."""
    global _db_client
    if _db_client is None:
        _db_client = create_client(settings.supabase_url, settings.supabase_service_key)
    return _db_client


def get_auth_client() -> Client:
    """Fresh client per auth request so sign-in/sign-up never pollute the
    shared DB client's session state."""
    return create_client(settings.supabase_url, settings.supabase_service_key)
