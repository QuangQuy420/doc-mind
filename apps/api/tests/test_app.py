"""Cross-cutting behaviour: 500 envelope (AC5), request log line (AC7), bare import (AC8)."""

import io
import json
import logging
import os
import subprocess
import sys
from collections.abc import Callable, Iterator

import pytest
import structlog
from app.core.deps import get_me_service
from app.main import app
from fastapi.testclient import TestClient

from tests.conftest import auth_header

REQUEST_LOG_FIELDS = {"request_id", "user_id", "path", "method", "status_code", "latency_ms"}


class _BrokenMeService:
    def get_profile(self, user: object) -> object:
        raise RuntimeError("secret database password leaked?")


@pytest.fixture
def json_log_lines() -> Iterator[io.StringIO]:
    """Capture stdlib log records rendered through the app's JSON formatter."""
    buffer = io.StringIO()
    handler = logging.StreamHandler(buffer)
    handler.setFormatter(
        structlog.stdlib.ProcessorFormatter(
            processors=[
                structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                structlog.processors.JSONRenderer(),
            ]
        )
    )
    root = logging.getLogger()
    root.addHandler(handler)
    try:
        yield buffer
    finally:
        root.removeHandler(handler)


def _request_completed_lines(buffer: io.StringIO) -> list[dict[str, object]]:
    lines = [json.loads(line) for line in buffer.getvalue().splitlines() if line.strip()]
    return [line for line in lines if line.get("event") == "request.completed"]


def test_unexpected_error_is_500_envelope_without_internals(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    app.dependency_overrides[get_me_service] = lambda: _BrokenMeService()

    response = client.get("/me", headers=auth_header(make_token()))

    assert response.status_code == 500
    assert response.json() == {
        "error": {"code": "INTERNAL_ERROR", "message": "Internal server error", "details": None}
    }
    assert "password" not in response.text


def test_each_request_logs_one_json_line(
    client: TestClient, make_token: Callable[..., str], json_log_lines: io.StringIO
) -> None:
    response = client.get(
        "/me", headers={**auth_header(make_token("user-a")), "X-Request-ID": "req-123"}
    )

    assert response.headers["X-Request-ID"] == "req-123"
    lines = _request_completed_lines(json_log_lines)
    assert len(lines) == 1
    line = lines[0]
    assert set(line) >= REQUEST_LOG_FIELDS
    assert line["request_id"] == "req-123"
    assert line["user_id"] == "user-a"
    assert line["path"] == "/me"
    assert line["method"] == "GET"
    assert line["status_code"] == 200
    assert isinstance(line["latency_ms"], int)


def test_request_id_is_generated_and_user_is_none_when_anonymous(
    client: TestClient, json_log_lines: io.StringIO
) -> None:
    response = client.get("/health")

    generated = response.headers["X-Request-ID"]
    assert generated
    (line,) = _request_completed_lines(json_log_lines)
    assert line["request_id"] == generated
    assert line["user_id"] is None
    assert line["status_code"] == 200


def test_app_imports_with_empty_environment() -> None:
    """The bare Docker image has no env vars; import must still work (AC8)."""
    result = subprocess.run(
        [sys.executable, "-c", "import app.main; print(app.main.app.title)"],
        env={"PATH": os.environ["PATH"]},
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "DocMind API"
