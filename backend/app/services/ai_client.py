"""Shared Gemini client for the `/ai/*` and `/couples/wrapped` endpoints.

Every AI endpoint goes through `ai_generate_structured()` so behavior is
consistent (model pinned in one place, no API key in code, graceful failure
when the key is missing, structured JSON validated into a Pydantic model).

Why Gemini (via its OpenAI-compatible endpoint):
  • Free tier — no per-call cost, which suits a hobby/personal app.
  • `gemini-2.5-flash` is multimodal, so the photo-parsing endpoint works
    with the same code path as the text endpoints.
  • We talk to it through the official `openai` SDK pointed at Gemini's
    OpenAI-compatible base URL. That SDK keeps httpx <0.28, staying
    compatible with supabase 2.10.0 (the native google-genai SDK would
    force httpx >=0.28 and break the supabase client).

`reasoning_effort="none"` disables Gemini 2.5's hidden "thinking" tokens.
Without it, thinking eats the `max_tokens` budget and the structured JSON
gets truncated (an intermittent `LengthFinishReasonError`).

`ai_unavailable()` is a small helper that returns a uniform 503 when the
API key isn't configured. Keeps every endpoint's error shape identical.
"""

from functools import lru_cache
from typing import TypeVar

from fastapi import HTTPException
from pydantic import BaseModel

from app.core.config import settings

# Single source of truth for the model ID — never inline literal model
# strings in endpoint code. `gemini-2.5-flash` is on Gemini's free tier and
# is multimodal (needed for /ai/parse-visit-photo).
AI_MODEL = "gemini-2.5-flash"

# Gemini's OpenAI-compatible endpoint. The `openai` SDK speaks to it natively
# when pointed here, so the same chat-completions / structured-output API the
# endpoints already used keeps working.
_GEMINI_OPENAI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/"

T = TypeVar("T", bound=BaseModel)


@lru_cache(maxsize=1)
def get_gemini_client():
    """Lazy singleton — the SDK only initializes on first AI request. Cached
    so we don't recreate the httpx client per request. Raises a uniform
    503 (not a 500) when the key isn't configured, since this is a
    deployment misconfig rather than a runtime bug.
    """
    if not settings.gemini_api_key:
        raise HTTPException(
            status_code=503,
            detail="AI features are not configured on this environment. "
            "Set GEMINI_API_KEY in the backend and redeploy.",
        )
    # Imported lazily so the rest of the API still boots on an environment
    # that hasn't installed the `openai` package yet (e.g. first deploy
    # before `pip install -r requirements.txt` runs against this revision).
    from openai import OpenAI

    return OpenAI(
        api_key=settings.gemini_api_key,
        base_url=_GEMINI_OPENAI_BASE_URL,
    )


def ai_generate_structured(
    *,
    system: str,
    user_text: str,
    schema: type[T],
    max_tokens: int = 2000,
    image: tuple[str, bytes] | None = None,
) -> T:
    """Single entry point for every AI feature.

    Sends `system` + `user_text` (and an optional `(mime, raw_bytes)` image)
    to Gemini and returns a validated instance of `schema`. Raises a uniform
    502 when the upstream call fails or the response can't be parsed, and a
    503 (via the client) when the API key is missing.
    """
    client = get_gemini_client()

    if image is not None:
        import base64

        mime, data = image
        b64 = base64.standard_b64encode(data).decode("ascii")
        user_content: object = [
            {"type": "text", "text": user_text},
            {
                "type": "image_url",
                "image_url": {"url": f"data:{mime};base64,{b64}"},
            },
        ]
    else:
        user_content = user_text

    try:
        completion = client.beta.chat.completions.parse(
            model=AI_MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_content},
            ],
            response_format=schema,
            max_tokens=max_tokens,
            # Disable Gemini 2.5 "thinking" so it doesn't spend the token
            # budget before emitting the JSON (would truncate the output).
            reasoning_effort="none",
        )
    except Exception as e:  # noqa: BLE001 — surface any upstream failure as 502
        raise HTTPException(status_code=502, detail=f"AI call failed: {e}") from e

    parsed = completion.choices[0].message.parsed
    if parsed is None:
        raise HTTPException(
            status_code=502, detail="AI returned an unparseable response."
        )
    return parsed


def ai_unavailable() -> HTTPException:
    """Return-style helper for endpoints that want to surface 503 without
    raising. Keeps the public error message consistent with the lazy
    initializer above.
    """
    return HTTPException(
        status_code=503,
        detail="AI features are not configured on this environment.",
    )
