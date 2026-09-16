from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy import URL

BACKEND_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_ROOT / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_name: str = "generatabla"
    db_username: str = "postgres"
    db_password: SecretStr = SecretStr("")
    database_url: str | None = None
    case_ai_chat_url: str | None = None
    case_ai_model: str | None = None
    case_ai_api_key: SecretStr = SecretStr("")

    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        url = URL.create(
            drivername="postgresql+psycopg",
            username=self.db_username,
            password=self.db_password.get_secret_value(),
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
        )
        return url.render_as_string(hide_password=False)


@lru_cache
def get_settings() -> Settings:
    return Settings()
