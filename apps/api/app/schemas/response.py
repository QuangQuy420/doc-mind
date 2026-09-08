"""The response envelope every JSON endpoint uses.

Success is `{"data": ...}`, a page is `{"data": [...], "meta": {...}}`, failure
is `{"error": {code, message, details}}`. One shape means the web client has one
unwrapper and branches on `code`, never on a message string.
"""

from typing import Any

from pydantic import BaseModel


class ApiResponse[T](BaseModel):
    """Success with a single resource."""

    data: T


class PageMeta(BaseModel):
    """Pagination info. `next_cursor` is opaque: pass it back untouched."""

    page: int
    page_size: int
    total: int
    has_next: bool
    next_cursor: str | None = None


class PaginatedResponse[T](BaseModel):
    """Success with a collection."""

    data: list[T]
    meta: PageMeta


class ErrorBody(BaseModel):
    code: str
    message: str
    details: Any | None = None


class ErrorResponse(BaseModel):
    error: ErrorBody
