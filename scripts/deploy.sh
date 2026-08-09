#!/usr/bin/env bash
# Pull latest + run tests in Docker, then rebuild/restart app services.
# Usage:
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh feature/public-tunnel-live-chart
#   SKIP_TESTS=1 ./scripts/deploy.sh   # emergency only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BRANCH="${1:-feature/public-tunnel-live-chart}"
SKIP_TESTS="${SKIP_TESTS:-0}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-statusgate}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-statusgate}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgresql+psycopg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/statusgate_test}"

echo "==> Pull ${BRANCH}"
git pull --ff-only "origin" "${BRANCH}"
git submodule update --init --recursive

echo "==> Ensure Postgres is up"
docker compose up -d db
for _ in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if [[ "${SKIP_TESTS}" != "1" ]]; then
  echo "==> Backend tests (Docker)"
  docker run --rm --network host \
    -v "${ROOT}/backend:/app" \
    -w /app \
    -e "JWT_SECRET=${JWT_SECRET:-deploy-check-jwt-secret-at-least-32-characters}" \
    -e "TEST_DATABASE_URL=${TEST_DATABASE_URL}" \
    python:3.14-slim \
    bash -c 'pip install -q -r requirements.txt -r requirements-dev.txt && pytest -q --tb=line'

  echo "==> Frontend tests + production build check (Docker)"
  docker run --rm \
    -v "${ROOT}/frontend:/app" \
    -w /app \
    node:22-alpine \
    sh -c 'npm ci && npm test && npm run build'
else
  echo "==> SKIP_TESTS=1 — skipping test gate"
fi

echo "==> Rebuild and restart app"
docker compose up -d --build frontend backend worker

echo "==> Done"
docker compose ps
