# DocMind

Personal document hub with AI: upload PDFs, extract and summarize them with Amazon Bedrock, ask
questions over them (RAG), get notified when processing finishes, receive a daily digest.

The app is an excuse. The real goal is a **solo AWS fullstack learning project** where every AWS
service has a concrete reason to exist and every trade-off can be explained out loud. The roadmap
lives in [`.plans/`](.plans/) — start with [`.plans/00-overview.md`](.plans/00-overview.md).

## Layout

| Path | What it is | Stack |
|---|---|---|
| `.plans/` | Phase plans (`0N-*.md`) and per-task plans in `.plans/tasks/` | markdown |
| `infra/` | All AWS resources: `bootstrap/` (state), `modules/`, `envs/dev/` | Terraform |
| `apps/api/` | HTTP API (Docker; EC2 in Phase 1, ECS Fargate in Phase 4) | Python 3.12 · FastAPI · SQLAlchemy 2 · Alembic · boto3 |
| `apps/web/` | Static SPA on S3 + CloudFront | React · TypeScript · Vite |
| `lambdas/*` | Event handlers (`process-document`, `notify`, `daily-digest`, …) | Python 3.12 · Powertools for AWS Lambda |
| `packages/shared/` | `docmind_shared`: Pydantic models, enums, event schemas | Python |

Folders arrive phase by phase: `infra/` in Phase 2 of the roadmap, `lambdas/*` later. Only the
paths that exist in the tree are built yet.

Python (`apps/api`, `lambdas/*`, `packages/shared`) is one **uv workspace** with a single
`uv.lock`, so the Docker image and the Lambda zips resolve identical versions. Node/npm is used
only for `apps/web`.

## Requirements

- Python 3.12 (`.python-version`) and [uv](https://docs.astral.sh/uv/)
- Node 24 (`.nvmrc`; `nvm install 24`) and npm
- Docker with Compose
- [pre-commit](https://pre-commit.com/)
- Terraform (needed from Phase 2 onwards, and by the terraform pre-commit hooks)

## Local development

```bash
# Python workspace - plain `uv sync` installs the root project only.
uv sync --all-packages

# Web workspace
npm install

# Local stores: Postgres 16 + pgvector on 5432, DynamoDB Local on 8000
docker compose up -d

# Git hooks (ruff, ruff-format, prettier, terraform fmt/validate)
pre-commit install
```

Enable pgvector in the local database once:

```bash
docker compose exec postgres psql -U docmind -c "CREATE EXTENSION IF NOT EXISTS vector"
```

Stop the local stores with `docker compose down` (add `-v` to drop the `pgdata` volume).

## Checks

```bash
uv run ruff check .          # lint
uv run ruff format --check . # format
uv run mypy                  # typecheck (strict; paths from pyproject.toml)
uv run pytest                # tests
pre-commit run --all-files   # everything the hooks would run
```

Web checks (once `apps/web` exists): `npm run lint -w apps/web` and `npm run build -w apps/web`.

## Notes

- Every AWS resource is created by Terraform. Nothing is clicked in the console.
- Costly, always-on resources sit behind Terraform toggles that default to off.
- `LEARNINGS.md` collects the interview-prep notes, one section per phase.
