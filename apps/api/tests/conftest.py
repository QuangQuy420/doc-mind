"""Shared fixtures for the API unit tests.

No real AWS: DynamoDB is moto, Cognito is an RSA key pair generated here and
handed to the app through a patched JWKS client, Postgres is a fake repository.
"""

import os
import time
from collections.abc import Iterator
from typing import Any

# Real env vars win over `apps/api/.env`, so these are stable no matter what the
# owner has in their local env file. They must be set before `app.main` is
# imported, because the settings are cached at import time.
TEST_ISSUER = "https://cognito-idp.test/pool"
TEST_CLIENT_ID = "test-client-id"
os.environ["COGNITO_ISSUER"] = TEST_ISSUER
os.environ["COGNITO_CLIENT_ID"] = TEST_CLIENT_ID
# moto needs credentials to exist; these are fake.
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
os.environ["AWS_DEFAULT_REGION"] = "ap-southeast-1"

import app.core.auth as auth_module  # noqa: E402
import boto3  # noqa: E402
import jwt  # noqa: E402
import pytest  # noqa: E402
from app.core.config import Settings, get_settings  # noqa: E402
from app.core.deps import get_health_repository, get_session  # noqa: E402
from app.main import app  # noqa: E402
from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from moto import mock_aws  # noqa: E402

TABLE_NAME = "docmind-dev-documents"


def _pem(key: rsa.RSAPrivateKey) -> str:
    return key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()


def _public_pem(key: rsa.RSAPrivateKey) -> str:
    return (
        key.public_key()
        .public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
        .decode()
    )


class _FakeSigningKey:
    def __init__(self, key: str) -> None:
        self.key = key


class _FakeJwksClient:
    """Stands in for PyJWKClient: always returns our test public key."""

    def __init__(self, public_pem: str) -> None:
        self._key = _FakeSigningKey(public_pem)

    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        return self._key


@pytest.fixture(scope="session")
def rsa_key() -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(scope="session")
def other_rsa_key() -> rsa.RSAPrivateKey:
    """A key the app does not trust, for the bad-signature case."""
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(autouse=True)
def _patch_jwks(monkeypatch: pytest.MonkeyPatch, rsa_key: rsa.RSAPrivateKey) -> None:
    """Never fetch a JWKS over the network."""
    fake = _FakeJwksClient(_public_pem(rsa_key))
    monkeypatch.setattr(auth_module, "_jwks_client", lambda issuer: fake)


@pytest.fixture
def make_token(rsa_key: rsa.RSAPrivateKey) -> Any:
    def _make(
        sub: str = "user-a",
        *,
        token_use: str = "access",
        client_id: str = TEST_CLIENT_ID,
        exp_delta: int = 3600,
        issuer: str = TEST_ISSUER,
        username: str | None = None,
        signing_key: rsa.RSAPrivateKey | None = None,
    ) -> str:
        now = int(time.time())
        claims: dict[str, Any] = {
            "sub": sub,
            "iss": issuer,
            "token_use": token_use,
            "client_id": client_id,
            "iat": now,
            "exp": now + exp_delta,
            "username": username or sub,
        }
        return jwt.encode(
            claims,
            _pem(signing_key or rsa_key),
            algorithm="RS256",
            headers={"kid": "test-kid"},
        )

    return _make


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def dynamodb_table() -> Iterator[Any]:
    """The documents table with the P5 schema, in moto."""
    with mock_aws():
        resource = boto3.resource("dynamodb", region_name="ap-southeast-1")
        table = resource.create_table(
            TableName=TABLE_NAME,
            BillingMode="PAY_PER_REQUEST",
            KeySchema=[
                {"AttributeName": "userId", "KeyType": "HASH"},
                {"AttributeName": "documentId", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "userId", "AttributeType": "S"},
                {"AttributeName": "documentId", "AttributeType": "S"},
                {"AttributeName": "status", "AttributeType": "S"},
                {"AttributeName": "createdAt", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "status-createdAt-index",
                    "KeySchema": [
                        {"AttributeName": "status", "KeyType": "HASH"},
                        {"AttributeName": "createdAt", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                }
            ],
        )
        yield table


class FakeHealthRepository:
    """Configurable stand-in for the Postgres round-trip."""

    def __init__(self, result: bool = True, error: Exception | None = None) -> None:
        self.result = result
        self.error = error

    def select_one(self, session: Any) -> bool:
        if self.error is not None:
            raise self.error
        return self.result


def make_settings(**overrides: Any) -> Settings:
    """Settings that ignore `.env`, so a test controls every value it cares about."""
    values: dict[str, Any] = {
        "cognito_issuer": TEST_ISSUER,
        "cognito_client_id": TEST_CLIENT_ID,
        "database_url": None,
        **overrides,
    }
    return Settings(_env_file=None, **values)


@pytest.fixture
def client(dynamodb_table: Any) -> Iterator[TestClient]:
    """App client with the lifespan skipped: state is injected, not created.

    `raise_server_exceptions=False` so the 500 handler is exercised instead of
    the exception bubbling into the test.
    """
    app.state.dynamodb_table = dynamodb_table
    app.state.session_factory = None
    app.dependency_overrides[get_settings] = lambda: make_settings()
    app.dependency_overrides[get_health_repository] = lambda: FakeHealthRepository()
    app.dependency_overrides[get_session] = lambda: None
    try:
        yield TestClient(app, raise_server_exceptions=False)
    finally:
        app.dependency_overrides.clear()
