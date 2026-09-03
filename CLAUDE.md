# CLAUDE.md — DocMind

Solo **AWS fullstack learning project**: a personal document hub (upload PDFs → extract → embed →
summarize with Bedrock → RAG chat → notifications → daily digest). The app is an excuse; the goal
is to touch every AWS service a senior fullstack dev should know, each with a real reason to exist,
and to be able to explain every trade-off in an interview. Single git repo (monorepo).

## Map
| Path | What it is | Stack |
|---|---|---|
| `.plans/` | Phase plans (`0N-*.md`, the owner's checklist) + per-task plans in `.plans/tasks/` | markdown |
| `infra/` | All AWS resources. `bootstrap/` (state), `modules/`, `envs/dev/` | Terraform |
| `apps/api/` | HTTP API (Dockerized; EC2 in Phase 1, ECS Fargate in Phase 4) | Python 3.12 · FastAPI · SQLAlchemy 2 · Alembic · boto3 |
| `apps/web/` | Static SPA on S3 + CloudFront | React · TypeScript · Vite |
| `lambdas/*` | Event handlers (`process-document`, `notify`, `daily-digest`, …) | Python 3.12 · Powertools for AWS Lambda |
| `packages/shared/` | `docmind_shared`: Pydantic models, enums, event schemas | Python |

Python is one **uv workspace** (ruff, mypy strict, pytest). Node/npm is used only for `apps/web`.
Tech choices are fixed in `.plans/00-overview.md` ("Tech choices") — implement them, don't debate
them. `LEARNINGS.md` is the owner's interview-prep notebook.

## The planning → implement → review workflow
Work is driven by the phase checklists in `.plans/0N-*.md` through per-task plan files and these
skills (`.claude/commands/`), run in order:
1. **`/dm-planning <phase task | goal>`** — phase task → source-grounded plan in
   `.plans/tasks/YYYY-MM-DD-*.md`.
2. **`/dm-verify-plan <plan>`** — adversarial readiness gate (PASS/CONCERNS/FAIL).
3. **`/dm-implement-plan <plan>`** — execute across areas, **code only (no tests)**.
4. *(owner)* `terraform apply`, try the change by hand.
5. **`/dm-unit-test [plan]`** — write + run unit tests for the current diff / newest commit.
6. **`/dm-code-review <plan>`** — QA gate against the plan; on PASS ticks the phase checkbox.

All skills **fan out one parallel teammate per in-scope area** (`infra`, `api`, `web`, `lambdas`,
`shared`) when >1 area is affected; cross-area contracts and synthesis stay with the orchestrator.

**Model routing:** the main session (Fable) orchestrates and never writes product code when
teammates are fanned out. Teammates that write or judge code (`/dm-implement-plan`,
`/dm-unit-test`, `/dm-code-review`) run with `model: opus`; read-only research teammates
(`/dm-planning`, `/dm-verify-plan`) run with `model: sonnet`.

## Coding & review standards (read before editing)
- **`.claude/refs/coder.md`** — per-area coding practices (Terraform modules/IAM/cost toggles,
  FastAPI layering, React state, Lambda idempotency) + per-area "definition of done".
- **`.claude/refs/reviewer.md`** — per-area review checklists, severity classes, cross-area
  contract check.

## Hard Rules (apply to every task and skill)
- **Do NOT commit, push, tag, or open PRs automatically.** Leave changes in the working tree; run
  git write commands only if the owner explicitly asks. Read-only git is fine.
- **Never touch real AWS resources.** No `terraform apply`/`destroy`/`import`/`state`, no
  mutating `aws` CLI commands, no `docker push`, no `aws s3 sync`. The owner runs those (cost +
  learning). Read-only (`terraform plan`, `aws … describe/list/get`) only when asked. List every
  manual step the owner must do.
- **Everything through Terraform.** Never suggest a console click as the solution; if something
  must be clicked once (model access, email confirmation), say so explicitly as an owner step.
- **Cost-aware by default.** Always-on billable resources (NAT, ALB, RDS, interface endpoints, ECS
  tasks) go behind toggle variables with cheap defaults; 7-day log retention; `maxTokens` caps.
- **Least privilege & tenant isolation.** No unjustified `*` in IAM; no public S3; secrets in
  SSM/Secrets Manager only; every data query filtered by `user_id`; LLM input is untrusted.
- **When unsure, ASK — don't guess.** Ambiguous requirement, contract, or behavior → stop and ask;
  the owner answers right away. A wrong guess wastes a whole re-run.
- **Formatters only on files you touched** (`ruff format`, `prettier`). Never repo-wide
  reformatting; it makes diffs unreviewable.
- **Minimal solution first**, match existing patterns, no unrelated drift. Don't pre-build later
  phases.
- **Explain the why.** Every AWS decision comes with a one-line trade-off in the report; suggest
  `LEARNINGS.md` lines but let the owner write them.
- **Never edit `.plans/0N-*.md`** except ticking a checkbox on a `/dm-code-review` PASS.

## API conventions (apps/api ↔ apps/web)
- **Layering:** `Route → Service → Repository → Database`, strictly. Routes are thin, services
  hold logic and never touch HTTP or I/O, repositories own all data access (Postgres, DynamoDB,
  S3, Bedrock). Details in `.claude/refs/coder.md` §4.
- **Response envelope, every JSON endpoint:**
  - success: `{ "data": ... }`
  - success + pagination: `{ "data": [...], "meta": { "page", "page_size", "total", "has_next" } }`
  - error: `{ "error": { "code": "UPPER_SNAKE", "message": "...", "details": ... } }`
  Errors are produced only by the global exception handlers; the web client unwraps `data`
  and throws a typed `ApiError` keyed by `code`.

## Conventions
- Branches: `feat/<slug>`, `fix/<slug>`, `infra/<slug>` from `main`; one PR per phase task.
- Commits (only when the owner asks): `feat(api): …`, `feat(infra): …`, `fix(lambdas): …`,
  `docs: …`.
- Ordering: `shared`/`infra` contracts (outputs, IAM, schemas) land before `api`/`lambdas`
  consume them; `web` last. Alembic migration before code that needs the column.
- Tags on every AWS resource via `default_tags`: `Project=docmind`, `Env=dev`,
  `ManagedBy=terraform`.
