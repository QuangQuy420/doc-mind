# Build context is the REPO ROOT (uv workspace): docker build -f apps/api/Dockerfile .
# syntax reminder for the owner:
#   docker buildx build --platform linux/arm64 -f apps/api/Dockerfile -t docmind-api:dev --load .

FROM python:3.12-slim AS builder

# Pinned, not :latest - a build must be reproducible.
COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /usr/local/bin/uv

WORKDIR /app

# `uv sync --frozen` validates the whole lockfile, so EVERY workspace member
# listed in uv.lock must exist in the context - even the ones this image does
# not run. When lambdas/* arrive in Phase 2, copy their pyproject.toml files here.
COPY pyproject.toml uv.lock ./
COPY packages/shared ./packages/shared
COPY apps/api ./apps/api

# The venv lands at /app/.venv, which is what the runtime PATH points at.
ENV UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy
RUN uv sync --frozen --no-dev --package docmind-api


FROM python:3.12-slim AS runtime

# Non-root: a container that cannot write its own filesystem cannot be
# repurposed as easily if the app is compromised.
RUN useradd --system --uid 1001 app

COPY --from=builder --chown=app:app /app /app

USER app
WORKDIR /app/apps/api
ENV PATH=/app/.venv/bin:$PATH \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# No curl in the slim image; python is already here.
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status==200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
