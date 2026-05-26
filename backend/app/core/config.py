from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GastroVoyage API"
    supabase_url: str
    supabase_service_key: str

    # Comma-separated list. Use a single wildcard "*" only for local dev.
    # Example: "https://gastrovoyage.app,https://staging.gastrovoyage.app"
    cors_origins: str = "http://localhost:*,http://10.0.2.2:*,http://127.0.0.1:*"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
