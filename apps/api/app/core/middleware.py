"""Request-scoped logging context."""

import time
import uuid
from collections.abc import Awaitable, Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

REQUEST_ID_HEADER = "X-Request-ID"

logger = structlog.get_logger(__name__)


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Bind request context to the logs and emit one `request.completed` line.

    An unhandled exception is re-raised after logging: the bare-`Exception`
    handler lives on Starlette's outermost ServerErrorMiddleware, so it runs
    above this middleware and turns the failure into the error envelope there.
    """

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        request_id = request.headers.get(REQUEST_ID_HEADER) or str(uuid.uuid4())
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            path=request.url.path,
            method=request.method,
        )
        started = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
        finally:
            structlog.contextvars.bind_contextvars(
                status_code=status_code,
                latency_ms=int((time.perf_counter() - started) * 1000),
                # Set by get_current_user; unauthenticated routes log None.
                user_id=getattr(request.state, "user_id", None),
            )
            logger.info("request.completed")

        response.headers[REQUEST_ID_HEADER] = request_id
        return response
