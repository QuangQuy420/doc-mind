"""Liveness/readiness logic."""

import structlog
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.exceptions import ServiceUnavailableError
from app.repository.postgres import HealthRepository
from app.schemas.health import HealthOut

logger = structlog.get_logger(__name__)


class HealthService:
    def __init__(
        self, repository: HealthRepository, session: Session | None, settings: Settings
    ) -> None:
        self._repository = repository
        self._session = session
        self._settings = settings

    def check(self) -> HealthOut:
        """Report the app and its database.

        When DATABASE_URL is unset there is nothing to check: report "error" and
        stay healthy on purpose, so the plain image (no env at all) still passes
        its Docker HEALTHCHECK. Once a database *is* configured, a failing check
        is a real outage and becomes a 503.
        """
        if self._settings.database_url is None:
            return HealthOut(status="ok", database="error", version=self._settings.app_version)

        try:
            if self._session is None or not self._repository.select_one(self._session):
                raise ServiceUnavailableError("Database is not reachable")
        except SQLAlchemyError as exc:
            logger.warning("health.database_unavailable", error=str(exc))
            raise ServiceUnavailableError("Database is not reachable") from exc

        return HealthOut(status="ok", database="ok", version=self._settings.app_version)
