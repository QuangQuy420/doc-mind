# docmind-api

FastAPI service: `GET /health`, `GET /me`, `GET|POST /documents`.
Layering is strict — `Route (app/api) → Service (app/services) → Repository (app/repository) → DB/AWS`.
Every JSON response uses the envelope (`{"data": …}` / `{"data": [...], "meta": {...}}` /
`{"error": {code, message, details}}`); only `app/handlers` produces the error shape.

## Run it locally

From the repo root:

```bash
docker compose up -d                     # postgres:5432, dynamodb-local:8000
cp apps/api/.env.example apps/api/.env    # then fill COGNITO_ISSUER / COGNITO_CLIENT_ID
terraform -chdir=infra/envs/dev output    # where those two values come from
```

Then from `apps/api` (`alembic.ini` and `scripts/` are resolved relative to it; `.env` is
found from any directory):

```bash
uv run --package docmind-api python scripts/create_local_table.py   # idempotent
uv run --package docmind-api alembic upgrade head
uv run --package docmind-api uvicorn app.main:app --reload --port 8001
```

DynamoDB Local already occupies port 8000, so pass `--port 8001` (or stop the container).

## Call it

```bash
TOKEN=$(aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH \
  --client-id <client_id> --auth-parameters USERNAME=<email>,PASSWORD=<pw> \
  --query AuthenticationResult.AccessToken --output text)

curl localhost:8001/health
curl -H "Authorization: Bearer $TOKEN" localhost:8001/me
curl -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"file_name":"notes.pdf"}' localhost:8001/documents
curl -H "Authorization: Bearer $TOKEN" 'localhost:8001/documents?limit=2'
```

Only Cognito *access* tokens are accepted (`token_use=access` and a matching `client_id`).

## Checks

From the repo root (`uv sync --all-packages` once first, so the workspace packages resolve):

```bash
uv run ruff check apps/api
uv run ruff format --check apps/api
uv run mypy apps/api
```

## OpenAPI schema

```bash
uv run --package docmind-api python -m app.export_openapi > openapi.json
```

`apps/web` generates its API types from that file.

## Container image

Build context is the repo root because the uv workspace lockfile spans the whole repo:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64        # once, for arm64 on x86
docker buildx build --platform linux/arm64 -f apps/api/Dockerfile -t docmind-api:dev --load .
docker run -d --rm --name docmind-api -p 8001:8000 docmind-api:dev
```

With no environment variables the image still serves `/health` with `"database": "error"` —
that is deliberate, so the `HEALTHCHECK` passes without a database.

## Migrations

```bash
uv run --package docmind-api alembic revision --autogenerate -m "add x"
uv run --package docmind-api alembic upgrade head
uv run --package docmind-api alembic downgrade -1
```

`alembic/env.py` reads `DATABASE_URL` from `Settings` and fails loudly when it is unset.
