"""Domain exceptions.

Services and repositories raise these; `app.handlers` is the only place that
turns one into an HTTP response, so the error envelope has a single producer.
"""

from typing import Any


class AppError(Exception):
    """Base class: every domain error carries its stable code and HTTP status."""

    code = "INTERNAL_ERROR"
    status_code = 500

    def __init__(self, message: str, details: Any | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details


class UnauthorizedError(AppError):
    code = "UNAUTHORIZED"
    status_code = 401


class ForbiddenError(AppError):
    code = "FORBIDDEN"
    status_code = 403


class NotFoundError(AppError):
    code = "NOT_FOUND"
    status_code = 404


class ValidationError(AppError):
    """Input that FastAPI cannot validate for us, e.g. an opaque cursor."""

    code = "VALIDATION_ERROR"
    status_code = 422


class ServiceUnavailableError(AppError):
    code = "SERVICE_UNAVAILABLE"
    status_code = 503


__all__ = [
    "AppError",
    "ForbiddenError",
    "NotFoundError",
    "ServiceUnavailableError",
    "UnauthorizedError",
    "ValidationError",
]
