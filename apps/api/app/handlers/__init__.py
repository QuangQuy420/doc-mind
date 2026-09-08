"""Exception -> HTTP mapping. The only producer of the error envelope."""

from typing import Any

import structlog
from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.exceptions import AppError
from app.schemas.response import ErrorBody, ErrorResponse

logger = structlog.get_logger(__name__)

# Pydantic puts the offending value in `input` and a docs link in `url`. The
# value can be user data we should not echo back, the link is noise.
_DROPPED_ERROR_KEYS = ("input", "url")


def _envelope(
    status_code: int, code: str, message: str, details: Any | None = None
) -> JSONResponse:
    body = ErrorResponse(error=ErrorBody(code=code, message=message, details=details))
    return JSONResponse(status_code=status_code, content=body.model_dump(mode="json"))


def register_exception_handlers(app: FastAPI) -> None:
    """Install the global handlers on the app."""

    @app.exception_handler(AppError)
    async def handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return _envelope(exc.status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        # jsonable_encoder: pydantic may put exception objects in `ctx`, which
        # would otherwise make serialising the 422 body itself fail.
        details = jsonable_encoder(
            [
                {k: v for k, v in error.items() if k not in _DROPPED_ERROR_KEYS}
                for error in exc.errors()
            ]
        )
        return _envelope(422, "VALIDATION_ERROR", "Request validation failed", details)

    # Starlette routes a bare-Exception handler through ServerErrorMiddleware
    # (outermost), so this runs above the other middleware — the response is
    # still the envelope, which is what the contract asks for.
    @app.exception_handler(Exception)
    async def handle_unexpected_error(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("request.unhandled_error", error=type(exc).__name__)
        return _envelope(500, "INTERNAL_ERROR", "Internal server error")
