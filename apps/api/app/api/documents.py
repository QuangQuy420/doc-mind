"""Document metadata endpoints.

Sync `def`: boto3 is blocking, so FastAPI runs these in its threadpool instead
of stalling the event loop.
"""

from typing import Annotated

from docmind_shared import Document
from fastapi import APIRouter, Depends, Query

from app.core.auth import CurrentUser, get_current_user
from app.core.deps import get_document_service
from app.schemas.documents import CreateDocumentRequest
from app.schemas.response import ApiResponse, PaginatedResponse
from app.services.documents import DocumentService

router = APIRouter(prefix="/documents", tags=["documents"])


@router.get("", response_model=PaginatedResponse[Document])
def list_documents(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    service: Annotated[DocumentService, Depends(get_document_service)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    cursor: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
) -> PaginatedResponse[Document]:
    # user_id comes from the verified token, never from the query string.
    documents, meta = service.list(user.user_id, limit, cursor, page)
    return PaginatedResponse(data=documents, meta=meta)


@router.post("", response_model=ApiResponse[Document], status_code=201)
def create_document(
    body: CreateDocumentRequest,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    service: Annotated[DocumentService, Depends(get_document_service)],
) -> ApiResponse[Document]:
    return ApiResponse(data=service.create(user.user_id, body.file_name))
