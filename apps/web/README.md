# apps/web

Vite + React + TypeScript SPA. Built to `dist/`, served from a private S3 bucket through
CloudFront (Origin Access Control). Login is the Cognito Hosted UI with authorization code + PKCE.

## Environment

Five `VITE_*` variables, all filled from `terraform -chdir=infra/envs/dev output`. See
`.env.example` for which output feeds which variable. They are validated once in `src/lib/env.ts`,
so a missing or malformed value fails loudly at startup instead of halfway through a login.

```bash
cp .env.example .env.local       # local dev, VITE_REDIRECT_URI=http://localhost:5173/
cp .env.example .env.production  # what `npm run build` bakes in, VITE_REDIRECT_URI=<site_url>/
```

Both files are git-ignored. `VITE_REDIRECT_URI` must end with `/`: it has to match a Cognito
callback URL exactly.

## API types

`src/lib/api.types.ts` is generated from the API's own OpenAPI schema and committed, so the client
cannot drift from the server:

```bash
npm run gen:api -w apps/web
```

It runs the API's `app.export_openapi` into `openapi.json` (git-ignored) and feeds it to
`openapi-typescript`. Re-run it whenever an endpoint or schema changes, and commit the result.

`openapi-typescript` is invoked as `npx --yes openapi-typescript@7.13.0` rather than installed as a
devDependency: it peer-depends on `typescript@^5` and this workspace is on TypeScript 6, so a clean
`npm install` would fail. The version is pinned and the output is committed, so nothing at build or
test time depends on that fetch.

## Local development

```bash
npm run dev -w apps/web    # http://localhost:5173
npm run lint -w apps/web
npm run build -w apps/web  # tsc -b && vite build
npm run test -w apps/web   # vitest, jsdom; tests live next to the code as *.test.ts(x)
```

`VITE_API_BASE_URL` decides which API the dev server talks to: `http://localhost:8001` for the
API run locally (see the root `README.md`, "Run the app locally") or the `api_url` output for the
one on EC2. `http://localhost:5173` is in the API's default and deployed `CORS_ORIGINS`, and it is
a Cognito callback URL, so login works from the dev server either way.

## Deploy (owner only)

```bash
SITE_BUCKET=$(terraform -chdir=infra/envs/dev output -raw site_bucket_name) \
CF_DIST_ID=$(terraform -chdir=infra/envs/dev output -raw cloudfront_distribution_id) \
npm run deploy -w apps/web
```

`scripts/deploy.sh` builds, uploads the content-hashed assets as `immutable`, uploads `index.html`
as `no-cache`, then invalidates `/` and `/index.html` (two cache keys at the edge). Hashed assets
never need invalidation because their file name changes.
