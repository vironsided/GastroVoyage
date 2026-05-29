"""Shared Anthropic client for the `/ai/*` and `/couples/wrapped` endpoints.

Every AI endpoint goes through `get_anthropic_client()` so behavior is
consistent (model pinned to Claude Opus 4.7, no API key in code, graceful
failure when the key is missing).

Why Opus 4.7:
  • Adaptive thinking is the only supported thinking mode.
  • Highest-quality reasoning for cuisine recommendations, multi-paragraph
    Wrapped narratives, and image understanding.
  • 1M context window at standard pricing — gives plenty of room when we
    pack a couple's full visit history into the prompt.

`ai_unavailable()` is a small helper that returns a uniform 503 when the
API key isn't configured (e.g. on a dev Render instance without the
secret). Keeps every endpoint's error shape identical.
"""

from functools import lru_cache

from fastapi import HTTPException

from app.core.config import settings

# Single source of truth for the model ID — never inline literal model
# strings in endpoint code. Per the Anthropic skill: do not add a date
# suffix to the alias, and default to the latest Opus for new code.
AI_MODEL = "claude-opus-4-7"


@lru_cache(maxsize=1)
def get_anthropic_client():
    """Lazy singleton — the SDK only initializes on first AI request. Cached
    so we don't recreate the httpx client per request. Raises a uniform
    503 (not a 500) when the key isn't configured, since this is a
    deployment misconfig rather than a runtime bug.
    """
    if not settings.anthropic_api_key:
        raise HTTPException(
            status_code=503,
            detail="AI features are not configured on this environment. "
            "Set ANTHROPIC_API_KEY in the backend and redeploy.",
        )
    # Imported lazily so the rest of the API still boots on an environment
    # that hasn't installed the `anthropic` package yet (e.g. first deploy
    # before `pip install -r requirements.txt` runs against this revision).
    from anthropic import Anthropic

    return Anthropic(api_key=settings.anthropic_api_key)


def ai_unavailable() -> HTTPException:
    """Return-style helper for endpoints that want to surface 503 without
    raising. Keeps the public error message consistent with the lazy
    initializer above.
    """
    return HTTPException(
        status_code=503,
        detail="AI features are not configured on this environment.",
    )
