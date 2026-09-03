from enum import StrEnum


class DocumentStatus(StrEnum):
    """Lifecycle of an uploaded document, from upload to searchable."""

    PENDING = "PENDING"
    EXTRACTED = "EXTRACTED"
    READY = "READY"
    FAILED = "FAILED"
