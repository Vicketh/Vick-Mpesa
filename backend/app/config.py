from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = "development"

    database_url: str = "sqlite+aiosqlite:///./vick_mpesa.db"

    daraja_base_url: str = "https://sandbox.safaricom.co.ke"
    daraja_consumer_key: str = ""
    daraja_consumer_secret: str = ""
    daraja_passkey: str = ""
    daraja_shortcode: str = "174379"
    daraja_callback_url: str = ""
    daraja_callback_secret: str = ""

    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 30

    api_key: str = ""

    allowed_origins: str = "http://localhost:3000"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]


@lru_cache
def get_settings() -> Settings:
    return Settings()
