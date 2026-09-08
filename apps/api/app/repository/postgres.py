"""Postgres access via SQLAlchemy."""

from sqlalchemy import text
from sqlalchemy.orm import Session


class HealthRepository:
    """The cheapest possible round-trip: proves the pool can reach the database."""

    def select_one(self, session: Session) -> bool:
        return int(session.execute(text("SELECT 1")).scalar_one()) == 1
