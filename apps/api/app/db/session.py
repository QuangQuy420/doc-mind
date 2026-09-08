"""SQLAlchemy engine and session factory."""

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker


def create_db_engine(url: str) -> Engine:
    """One engine per process; the pool is small because the EC2 box is small.

    pool_pre_ping costs one cheap round-trip per checkout and is what keeps the
    app alive when RDS drops idle connections overnight.
    """
    return create_engine(url, pool_pre_ping=True, pool_size=2, max_overflow=2)


def create_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, expire_on_commit=False)
