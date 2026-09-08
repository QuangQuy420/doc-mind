from pydantic import BaseModel, Field


class CreateDocumentRequest(BaseModel):
    """Phase 1 stub body. Phase 2 replaces this route with an upload-url flow."""

    file_name: str = Field(min_length=1, max_length=255)
