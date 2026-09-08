"""DynamoDB repository: attribute mapping and cursor validation (AC4)."""

import base64
from datetime import UTC, datetime, timedelta, timezone
from decimal import Decimal

import pytest
from app.exceptions import ValidationError
from app.repository.dynamodb import DocumentRepository, decode_cursor, encode_cursor
from docmind_shared import Document, DocumentStatus


def _document(**overrides: object) -> Document:
    values: dict[str, object] = {
        "document_id": "doc-1",
        "user_id": "user-a",
        "file_name": "a.pdf",
        "status": DocumentStatus.PENDING,
        "created_at": datetime(2026, 9, 8, 12, 0, 0, tzinfo=UTC),
        "expires_at": None,
    }
    values.update(overrides)
    return Document(**values)


def test_to_item_uses_camel_case_and_utc_z_timestamp() -> None:
    plus_seven = timezone(timedelta(hours=7))
    document = _document(created_at=datetime(2026, 9, 8, 19, 0, 0, tzinfo=plus_seven))

    item = DocumentRepository._to_item(document)

    assert item == {
        "userId": "user-a",
        "documentId": "doc-1",
        "fileName": "a.pdf",
        "status": "PENDING",
        "createdAt": "2026-09-08T12:00:00.000000Z",
    }
    assert "expiresAt" not in item


def test_expires_at_round_trips_as_number() -> None:
    document = _document(expires_at=1_800_000_000)

    item = DocumentRepository._to_item(document)
    assert item["expiresAt"] == 1_800_000_000

    # boto3's resource API hands numbers back as Decimal.
    item["expiresAt"] = Decimal(1_800_000_000)
    restored = DocumentRepository._from_item(item)
    assert restored == document


def test_from_item_restores_aware_datetime() -> None:
    document = _document()

    restored = DocumentRepository._from_item(DocumentRepository._to_item(document))

    assert restored == document
    assert restored.created_at.tzinfo is not None


def test_cursor_round_trip() -> None:
    key = {"userId": "user-a", "documentId": "doc-1"}

    cursor = encode_cursor(key)

    assert "=" not in cursor
    assert decode_cursor(cursor, "user-a") == key


# A valid base64url JSON array: decodes fine but is not a key object.
_NOT_AN_OBJECT = base64.urlsafe_b64encode(b'["userId","documentId"]').decode().rstrip("=")


@pytest.mark.parametrize(
    "cursor",
    [
        pytest.param("%%%", id="bad-base64"),
        pytest.param(_NOT_AN_OBJECT, id="not-an-object"),
        pytest.param(encode_cursor({"userId": "user-a"}), id="missing-key"),
        pytest.param(
            encode_cursor({"userId": "user-a", "documentId": "d", "x": 1}), id="extra-key"
        ),
        pytest.param(encode_cursor({"userId": "user-b", "documentId": "d"}), id="other-user"),
    ],
)
def test_decode_cursor_rejects_untrusted_input(cursor: str) -> None:
    with pytest.raises(ValidationError) as excinfo:
        decode_cursor(cursor, "user-a")

    assert excinfo.value.code == "VALIDATION_ERROR"
    assert excinfo.value.status_code == 422
