"""Settings: comma-separated CORS_ORIGINS (P8 contract) and harmless defaults (AC8)."""

import pytest
from app.core.config import Settings


def test_cors_origins_from_comma_string(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CORS_ORIGINS", "https://app.example.com, http://localhost:5173,")

    settings = Settings(_env_file=None)

    assert settings.cors_origins == ["https://app.example.com", "http://localhost:5173"]


def test_cors_origins_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CORS_ORIGINS", raising=False)

    settings = Settings(_env_file=None)

    assert settings.cors_origins == ["http://localhost:5173"]


def test_defaults_need_no_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in (
        "AWS_REGION",
        "DYNAMODB_TABLE_NAME",
        "DYNAMODB_ENDPOINT_URL",
        "COGNITO_ISSUER",
        "COGNITO_CLIENT_ID",
        "DATABASE_URL",
        "LOG_LEVEL",
        "APP_VERSION",
    ):
        monkeypatch.delenv(name, raising=False)

    settings = Settings(_env_file=None)

    assert settings.dynamodb_table_name == "docmind-dev-documents"
    assert settings.dynamodb_endpoint_url is None
    assert settings.database_url is None
    assert settings.aws_region == "ap-southeast-1"
