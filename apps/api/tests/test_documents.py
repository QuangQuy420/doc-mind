"""AC3/AC4/AC5: create + list documents, tenant isolation, cursor handling."""

from collections.abc import Callable

from app.repository.dynamodb import encode_cursor
from fastapi.testclient import TestClient

from tests.conftest import auth_header


def _create(client: TestClient, token: str, file_name: str = "a.pdf") -> dict[str, object]:
    response = client.post("/documents", json={"file_name": file_name}, headers=auth_header(token))
    assert response.status_code == 201, response.text
    data: dict[str, object] = response.json()["data"]
    return data


def test_create_document_returns_201_pending(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    data = _create(client, make_token("user-a"), "report.pdf")

    assert data["status"] == "PENDING"
    assert data["file_name"] == "report.pdf"
    assert data["user_id"] == "user-a"
    assert data["expires_at"] is None
    assert isinstance(data["document_id"], str) and data["document_id"]


def test_create_document_empty_name_is_422_with_field_details(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    response = client.post("/documents", json={"file_name": ""}, headers=auth_header(make_token()))

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert error["details"][0]["loc"] == ["body", "file_name"]
    # The offending value and the pydantic docs link are stripped.
    assert "input" not in error["details"][0]
    assert "url" not in error["details"][0]


def test_create_document_requires_token(client: TestClient) -> None:
    response = client.post("/documents", json={"file_name": "a.pdf"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


def test_list_paginates_with_cursor_and_total(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    token = make_token("user-a")
    for name in ("1.pdf", "2.pdf", "3.pdf"):
        _create(client, token, name)

    first = client.get("/documents", params={"limit": 2}, headers=auth_header(token)).json()
    assert len(first["data"]) == 2
    assert first["meta"] == {
        "page": 1,
        "page_size": 2,
        "total": 3,
        "has_next": True,
        "next_cursor": first["meta"]["next_cursor"],
    }
    assert first["meta"]["next_cursor"]

    second = client.get(
        "/documents",
        params={"limit": 2, "cursor": first["meta"]["next_cursor"], "page": 2},
        headers=auth_header(token),
    ).json()
    assert len(second["data"]) == 1
    assert second["meta"]["page"] == 2
    assert second["meta"]["has_next"] is False
    assert second["meta"]["next_cursor"] is None

    seen = {d["document_id"] for d in first["data"] + second["data"]}
    assert len(seen) == 3


def test_list_is_scoped_to_the_caller(client: TestClient, make_token: Callable[..., str]) -> None:
    _create(client, make_token("user-a"))

    response = client.get("/documents", headers=auth_header(make_token("user-b")))

    assert response.status_code == 200
    assert response.json() == {
        "data": [],
        "meta": {"page": 1, "page_size": 20, "total": 0, "has_next": False, "next_cursor": None},
    }


def test_list_rejects_garbage_cursor(client: TestClient, make_token: Callable[..., str]) -> None:
    response = client.get(
        "/documents", params={"cursor": "not-a-cursor"}, headers=auth_header(make_token())
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_list_rejects_another_users_cursor(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    """A cursor issued to user A must not page through A's items for user B."""
    token_a = make_token("user-a")
    for name in ("1.pdf", "2.pdf"):
        _create(client, token_a, name)
    cursor_a = client.get("/documents", params={"limit": 1}, headers=auth_header(token_a)).json()[
        "meta"
    ]["next_cursor"]
    assert cursor_a

    response = client.get(
        "/documents", params={"cursor": cursor_a}, headers=auth_header(make_token("user-b"))
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_list_rejects_forged_cursor_with_extra_keys(
    client: TestClient, make_token: Callable[..., str]
) -> None:
    forged = encode_cursor({"userId": "user-a", "documentId": "x", "status": "READY"})

    response = client.get(
        "/documents", params={"cursor": forged}, headers=auth_header(make_token("user-a"))
    )

    assert response.status_code == 422


def test_list_limit_out_of_range_is_422(client: TestClient, make_token: Callable[..., str]) -> None:
    response = client.get("/documents", params={"limit": 101}, headers=auth_header(make_token()))

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
