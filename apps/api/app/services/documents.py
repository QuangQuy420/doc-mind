"""Document use cases. No HTTP, no boto3 — only repositories and rules."""

import uuid
from datetime import UTC, datetime

from docmind_shared import Document, DocumentStatus

from app.repository.dynamodb import DocumentRepository
from app.schemas.response import PageMeta


class DocumentService:
    def __init__(self, repository: DocumentRepository) -> None:
        self._repository = repository

    def create(self, user_id: str, file_name: str) -> Document:
        """Phase 1 stub: metadata only. Phase 2 adds the S3 upload URL."""
        document = Document(
            document_id=str(uuid.uuid4()),
            user_id=user_id,
            file_name=file_name,
            status=DocumentStatus.PENDING,
            created_at=datetime.now(UTC),
        )
        self._repository.put(document)
        return document

    def list(
        self, user_id: str, limit: int, cursor: str | None, page: int
    ) -> tuple[list[Document], PageMeta]:
        """One page of the caller's documents.

        `page` is passed through for the client's benefit only: DynamoDB paging
        is cursor-based, there is no way to jump to an arbitrary page number.
        """
        documents, next_cursor = self._repository.list_by_user(user_id, limit, cursor)
        meta = PageMeta(
            page=page,
            page_size=limit,
            total=self._repository.count_by_user(user_id),
            has_next=next_cursor is not None,
            next_cursor=next_cursor,
        )
        return documents, meta
