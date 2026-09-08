"""AC1: /health envelope, 503 when the configured database fails."""

from app.core.config import get_settings
from app.core.deps import get_health_repository, get_session
from app.main import app
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from tests.conftest import FakeHealthRepository, make_settings

DB_URL = "postgresql+psycopg://docmind:docmind@localhost:5432/docmind"


def test_health_ok_with_database(client: TestClient) -> None:
    app.dependency_overrides[get_settings] = lambda: make_settings(
        database_url=DB_URL, app_version="9.9.9"
    )
    app.dependency_overrides[get_session] = lambda: object()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"data": {"status": "ok", "database": "ok", "version": "9.9.9"}}


def test_health_503_when_database_check_fails(client: TestClient) -> None:
    app.dependency_overrides[get_settings] = lambda: make_settings(database_url=DB_URL)
    app.dependency_overrides[get_session] = lambda: object()
    app.dependency_overrides[get_health_repository] = lambda: FakeHealthRepository(
        error=OperationalError("SELECT 1", {}, Exception("connection refused"))
    )

    response = client.get("/health")

    assert response.status_code == 503
    body = response.json()
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE"
    assert "connection refused" not in body["error"]["message"]


def test_health_reports_error_but_stays_200_without_database_url(client: TestClient) -> None:
    """The bare Docker image (no env) must still pass its HEALTHCHECK."""
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["data"]["database"] == "error"
