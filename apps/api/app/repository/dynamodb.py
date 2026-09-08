"""DynamoDB access for the `documents` table.

The only place boto3 is used for documents. Attribute names are camelCase here
(the table's contract, see infra/modules/dynamodb) and snake_case above, so the
mapping lives in this module and nowhere else.
"""

import base64
import binascii
import json
from datetime import UTC, datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from boto3.dynamodb.conditions import Key
from docmind_shared import Document, DocumentStatus

from app.exceptions import ValidationError

if TYPE_CHECKING:
    from mypy_boto3_dynamodb.service_resource import Table
else:  # boto3-stubs is a dev-only dependency: keep the runtime free of it.
    Table = Any

# The table's key attributes; a cursor is a LastEvaluatedKey, so it holds exactly these.
_KEY_ATTRIBUTES = {"userId", "documentId"}


def _to_iso(value: datetime) -> str:
    """UTC ISO-8601 with a trailing Z.

    `createdAt` is the `S` sort key of the status-createdAt GSI, so the string
    must be fixed width for lexicographic order to equal chronological order.
    """
    return value.astimezone(UTC).replace(tzinfo=None).isoformat(timespec="microseconds") + "Z"


def _from_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def encode_cursor(key: dict[str, Any]) -> str:
    """Pack a LastEvaluatedKey into an opaque, URL-safe string."""
    raw = json.dumps(key, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def decode_cursor(cursor: str, user_id: str) -> dict[str, str]:
    """Unpack a cursor. Untrusted input: anything unexpected is a 422, not a 500.

    Without these checks a hand-written cursor reaches DynamoDB and comes back as
    a `ValidationException` (a 500 for the caller) — or, worse, pages through
    another user's items.
    """
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        decoded = json.loads(base64.urlsafe_b64decode(padded))
    except (binascii.Error, ValueError) as exc:
        raise ValidationError("Invalid cursor") from exc

    if not isinstance(decoded, dict) or set(decoded) != _KEY_ATTRIBUTES:
        raise ValidationError("Invalid cursor")
    if decoded["userId"] != user_id:
        raise ValidationError("Invalid cursor")
    return {"userId": str(decoded["userId"]), "documentId": str(decoded["documentId"])}


class DocumentRepository:
    """Reads and writes document metadata. Every call is scoped to one user."""

    def __init__(self, table: "Table") -> None:
        self._table = table

    def put(self, document: Document) -> None:
        """Insert a new document. The condition makes a re-put a failure, not a silent overwrite."""
        self._table.put_item(
            Item=self._to_item(document),
            ConditionExpression="attribute_not_exists(documentId)",
        )

    def list_by_user(
        self, user_id: str, limit: int, cursor: str | None = None
    ) -> tuple[list[Document], str | None]:
        """One page of the caller's documents plus the cursor for the next page.

        ScanIndexForward=False walks the sort key backwards, and the sort key is
        `documentId` (a uuid4) — so in Phase 1 the list order is unspecified, not
        newest-first. Ordering by time needs the status-createdAt GSI (Phase 2).
        """
        params: dict[str, Any] = {
            "KeyConditionExpression": Key("userId").eq(user_id),
            "Limit": limit,
            "ScanIndexForward": False,
        }
        if cursor is not None:
            params["ExclusiveStartKey"] = decode_cursor(cursor, user_id)

        response = self._table.query(**params)
        documents = [self._from_item(item) for item in response.get("Items", [])]
        last_key = response.get("LastEvaluatedKey")
        return documents, encode_cursor(dict(last_key)) if last_key else None

    def count_by_user(self, user_id: str) -> int:
        """Total documents of one user.

        Select=COUNT still reads every matching item server-side and is paginated
        like any query, hence the loop. It is a second query per list call —
        acceptable at dev scale, a counter attribute is the fix if it ever isn't.
        """
        total = 0
        start_key: dict[str, Any] | None = None
        while True:
            params: dict[str, Any] = {
                "KeyConditionExpression": Key("userId").eq(user_id),
                "Select": "COUNT",
            }
            if start_key is not None:
                params["ExclusiveStartKey"] = start_key
            response = self._table.query(**params)
            total += int(response.get("Count", 0))
            start_key = response.get("LastEvaluatedKey")
            if not start_key:
                return total

    @staticmethod
    def _to_item(document: Document) -> dict[str, Any]:
        item: dict[str, Any] = {
            "userId": document.user_id,
            "documentId": document.document_id,
            "fileName": document.file_name,
            "status": document.status.value,
            "createdAt": _to_iso(document.created_at),
        }
        # TTL: an absent attribute means "never expires", so omit it rather than
        # writing null (DynamoDB would never expire the item either way, but the
        # attribute type must be Number when present).
        if document.expires_at is not None:
            item["expiresAt"] = document.expires_at
        return item

    @staticmethod
    def _from_item(item: dict[str, Any]) -> Document:
        expires_at = item.get("expiresAt")
        return Document(
            document_id=str(item["documentId"]),
            user_id=str(item["userId"]),
            file_name=str(item["fileName"]),
            status=DocumentStatus(item["status"]),
            created_at=_from_iso(str(item["createdAt"])),
            # boto3's resource API returns numbers as Decimal.
            expires_at=int(expires_at) if isinstance(expires_at, Decimal | int) else None,
        )
