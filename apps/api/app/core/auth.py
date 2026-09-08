"""Cognito access-token verification.

The JWKS is fetched lazily on the first verified request (never at import, so
`import app.main` needs no network) and cached per process by PyJWKClient;
`kid` picks the right key, which is what makes key rotation a non-event.
"""

from dataclasses import dataclass
from functools import lru_cache
from typing import Annotated, Any

import jwt
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import Settings, get_settings
from app.exceptions import UnauthorizedError

# auto_error=False: FastAPI would otherwise raise its own 401 with a bare
# {"detail": ...} body, bypassing the error envelope.
_bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    """The authenticated caller. `user_id` is the Cognito `sub`."""

    user_id: str
    username: str


@lru_cache
def _jwks_client(issuer: str) -> jwt.PyJWKClient:
    """One JWKS client per issuer per process; it caches the signing keys."""
    return jwt.PyJWKClient(f"{issuer}/.well-known/jwks.json", cache_keys=True)


def _decode(token: str, settings: Settings) -> dict[str, Any]:
    signing_key = _jwks_client(settings.cognito_issuer).get_signing_key_from_jwt(token)
    claims: dict[str, Any] = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        issuer=settings.cognito_issuer,
        # Cognito access tokens carry `client_id`, not `aud` (only ID tokens do),
        # so audience validation is replaced by the explicit check below.
        options={"verify_aud": False},
    )
    if claims["token_use"] != "access":
        raise UnauthorizedError("Invalid or expired token")
    if claims["client_id"] != settings.cognito_client_id:
        raise UnauthorizedError("Invalid or expired token")
    return claims


def get_current_user(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)],
) -> CurrentUser:
    """Verify the bearer token and return the caller."""
    if credentials is None:
        raise UnauthorizedError("Missing bearer token")

    settings = get_settings()
    try:
        claims = _decode(credentials.credentials, settings)
    except (jwt.PyJWTError, KeyError) as exc:
        raise UnauthorizedError("Invalid or expired token") from exc

    user_id = claims["sub"]
    # The logging middleware reads this after the response.
    request.state.user_id = user_id
    return CurrentUser(user_id=user_id, username=claims.get("username", user_id))
