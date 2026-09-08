"""Application settings.

12-factor: every knob is an environment variable, read once through
pydantic-settings. Every setting has a harmless local default so that
`import app.main` and the OpenAPI export work with no environment and no AWS
account at all (the bare Docker image must start and answer /health).
"""

from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, loaded from the environment (or `apps/api/.env`)."""

    aws_region: str = "ap-southeast-1"

    dynamodb_table_name: str = "docmind-dev-documents"
    # None = the real AWS endpoint for the region; set to http://localhost:8000
    # to talk to DynamoDB Local from docker-compose.
    dynamodb_endpoint_url: str | None = None

    cognito_issuer: str = "http://localhost/unset-issuer"
    cognito_client_id: str = "unset"

    # None = no Postgres configured; /health then reports database "error"
    # instead of failing, so the bare image is still usable.
    database_url: str | None = None

    # NoDecode is required: pydantic-settings JSON-decodes complex (list) env
    # values *before* validators run, so "https://a,http://b" would blow up.
    # With NoDecode the raw string reaches the validator below.
    cors_origins: Annotated[list[str], NoDecode] = ["http://localhost:5173"]

    log_level: str = "INFO"
    app_version: str = "0.1.0"

    model_config = SettingsConfigDict(
        # Resolved from this file, not the cwd: `uvicorn`, `alembic` and the
        # scripts are started from different directories.
        env_file=Path(__file__).resolve().parents[2] / ".env",
        extra="ignore",
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_cors_origins(cls, value: object) -> object:
        """Accept a comma-separated string: CORS_ORIGINS="https://a,http://b"."""
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    """One Settings instance per process (parsing the env on every call is waste)."""
    return Settings()
