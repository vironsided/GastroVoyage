from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GastroVoyage API"
    supabase_url: str
    supabase_service_key: str

    # Comma-separated list. Use a single wildcard "*" only for local dev.
    # Example: "https://gastrovoyage.app,https://staging.gastrovoyage.app"
    cors_origins: str = "http://localhost:*,http://10.0.2.2:*,http://127.0.0.1:*"

    # Optional regex pattern matched against the Origin header. Lets us accept
    # ephemeral Vercel preview URLs without redeploying every time. Example:
    #   r"https://gastrovoyage(-[a-z0-9]+)?\.vercel\.app"
    cors_origin_regex: str | None = None

    # Google Gemini API key for AI-powered features (date-night picker,
    # cuisine recommendations, photo parsing, couple wrapped). Optional —
    # every `/ai/...` endpoint degrades to a 503 when this is unset rather
    # than crashing on import, so non-AI endpoints stay healthy on
    # misconfigured environments. Get a free key at
    # https://aistudio.google.com/apikey
    gemini_api_key: str | None = None

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
