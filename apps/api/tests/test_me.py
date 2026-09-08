"""AC2: /me with a Cognito access token; every bad token is a 401 envelope."""

from collections.abc import Callable
from typing import Any

import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from tests.conftest import auth_header


def test_me_returns_sub_and_username(client: TestClient, make_token: Callable[..., str]) -> None:
    token = make_token("user-a", username="alice")

    response = client.get("/me", headers=auth_header(token))

    assert response.status_code == 200
    assert response.json() == {"data": {"user_id": "user-a", "username": "alice"}}


def test_me_without_header_is_401(client: TestClient) -> None:
    response = client.get("/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


@pytest.mark.parametrize(
    "token_kwargs",
    [
        pytest.param({"exp_delta": -60}, id="expired"),
        pytest.param({"token_use": "id"}, id="id-token"),
        pytest.param({"client_id": "another-app"}, id="wrong-client"),
        pytest.param({"issuer": "https://evil.test/pool"}, id="wrong-issuer"),
    ],
)
def test_me_rejects_bad_claims(
    client: TestClient, make_token: Callable[..., str], token_kwargs: dict[str, Any]
) -> None:
    response = client.get("/me", headers=auth_header(make_token(**token_kwargs)))

    assert response.status_code == 401
    assert response.json()["error"] == {
        "code": "UNAUTHORIZED",
        "message": "Invalid or expired token",
        "details": None,
    }


def test_me_rejects_bad_signature(
    client: TestClient, make_token: Callable[..., str], other_rsa_key: rsa.RSAPrivateKey
) -> None:
    token = make_token(signing_key=other_rsa_key)

    response = client.get("/me", headers=auth_header(token))

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"
