#!/usr/bin/env bash
# Build the SPA and publish it to S3 behind CloudFront.
#
# Run by the OWNER only (it writes to real AWS):
#   SITE_BUCKET=$(terraform -chdir=infra/envs/dev output -raw site_bucket_name) \
#   CF_DIST_ID=$(terraform -chdir=infra/envs/dev output -raw cloudfront_distribution_id) \
#   npm run deploy -w apps/web
set -euo pipefail

: "${SITE_BUCKET:?set SITE_BUCKET (terraform output site_bucket_name)}"
: "${CF_DIST_ID:?set CF_DIST_ID (terraform output cloudfront_distribution_id)}"

cd "$(dirname "$0")/.."

# Without it `vite build` still succeeds, but env.ts throws in the browser and
# the live site is a blank page. Fail here instead.
[ -f .env.production ] || {
  echo "apps/web/.env.production is missing (copy .env.example and fill it from terraform output)" >&2
  exit 1
}

npm run build

# 1. Hashed assets first: Vite puts a content hash in every asset file name, so
#    a changed file is a new name and the old URL can be cached forever. Upload
#    them before index.html, otherwise the new index.html could point at assets
#    that are not there yet. --delete drops assets from previous builds.
#    NOTE: this header hits everything in dist/ except index.html. Vite copies
#    public/ through UNHASHED, so if a favicon or robots.txt ever lands there,
#    give it its own `aws s3 cp` with a short max-age instead.
aws s3 sync dist/ "s3://${SITE_BUCKET}" \
  --delete \
  --exclude index.html \
  --cache-control "public,max-age=31536000,immutable"

# 2. index.html is the one file whose name never changes, so it must never be
#    cached by the browser: no-cache means "revalidate before reuse".
aws s3 cp dist/index.html "s3://${SITE_BUCKET}/index.html" \
  --cache-control "no-cache"

# 3. The edge still holds the old index.html. `/` (the default root object) and
#    `/index.html` are two separate cache keys, so both must be invalidated.
#    Hashed assets never need invalidation — their URL changes instead.
aws cloudfront create-invalidation \
  --distribution-id "${CF_DIST_ID}" \
  --paths "/" "/index.html"
