"""Dependency injection wiring.

Long-lived resources (the DynamoDB Table, the SQLAlchemy engine) are created
once in the lifespan and read from `app.state` here, so nothing constructs a
client per request and tests can swap `app.state` for a fake.
"""

from collections.abc import Iterator
from typing import TYPE_CHECKING, Annotated, Any

from fastapi import Depends, Request
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings, get_settings
from app.repository.dynamodb import DocumentRepository
from app.repository.postgres import HealthRepository
from app.services.documents import DocumentService
from app.services.health import HealthService
from app.services.me import MeService

if TYPE_CHECKING:
    from mypy_boto3_dynamodb.service_resource import Table
else:  # boto3-stubs is a dev-only dependency: keep the runtime free of it.
    Table = Any


def get_dynamodb_table(request: Request) -> "Table":
    table: Table = request.app.state.dynamodb_table
    return table


def get_document_repository(
    table: Annotated["Table", Depends(get_dynamodb_table)],
) -> DocumentRepository:
    return DocumentRepository(table)


def get_health_repository() -> HealthRepository:
    return HealthRepository()


def get_session(request: Request) -> Iterator[Session | None]:
    """A database session, or None when no DATABASE_URL is configured.

    The image must start and answer /health without Postgres (see HealthService),
    so "no database" is a normal state here rather than an error.
    """
    factory: sessionmaker[Session] | None = getattr(request.app.state, "session_factory", None)
    if factory is None:
        yield None
        return
    with factory() as session:
        yield session


def get_document_service(
    repository: Annotated[DocumentRepository, Depends(get_document_repository)],
) -> DocumentService:
    return DocumentService(repository)


def get_health_service(
    repository: Annotated[HealthRepository, Depends(get_health_repository)],
    session: Annotated[Session | None, Depends(get_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> HealthService:
    return HealthService(repository, session, settings)


def get_me_service() -> MeService:
    return MeService()
