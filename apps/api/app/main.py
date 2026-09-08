"""FastAPI application factory and process-wide wiring."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import boto3
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import documents, health, me
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.middleware import RequestContextMiddleware
from app.db.session import create_db_engine, create_session_factory
from app.handlers import register_exception_handlers

settings = get_settings()
configure_logging(settings.log_level)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create the long-lived clients once and hand them to the request scope.

    Nothing here talks to AWS: boto3 resolves credentials and endpoints lazily,
    so the app starts (and /health answers) with no network and no credentials.
    """
    dynamodb = boto3.resource(
        "dynamodb",
        region_name=settings.aws_region,
        # None = the real regional endpoint; set for DynamoDB Local.
        endpoint_url=settings.dynamodb_endpoint_url,
    )
    app.state.dynamodb_table = dynamodb.Table(settings.dynamodb_table_name)

    engine = create_db_engine(settings.database_url) if settings.database_url else None
    app.state.db_engine = engine
    app.state.session_factory = create_session_factory(engine) if engine else None

    try:
        yield
    finally:
        if engine is not None:
            engine.dispose()


app = FastAPI(
    title="DocMind API",
    version=settings.app_version,
    lifespan=lifespan,
)

# Exactly the configured origins: the SPA on CloudFront and the local dev server.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
)
app.add_middleware(RequestContextMiddleware)

register_exception_handlers(app)

app.include_router(health.router)
app.include_router(me.router)
app.include_router(documents.router)
