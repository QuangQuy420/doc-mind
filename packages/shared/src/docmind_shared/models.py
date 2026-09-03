from datetime import datetime

from pydantic import BaseModel, ConfigDict

from docmind_shared.enums import DocumentStatus


class Document(BaseModel):
    """A document owned by one user. Frozen: build a new one instead of mutating."""

    model_config = ConfigDict(frozen=True)

    document_id: str
    user_id: str
    file_name: str
    status: DocumentStatus
    created_at: datetime
    expires_at: int | None = None
