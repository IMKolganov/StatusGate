#!/usr/bin/env bash
# Optional helper: pull + run tests in Docker + compose rebuild.
# You can keep deploying with plain `docker compose up -d --build` — this script
# only exists if you want a test gate before rebuild.
#
# Usage:
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh feature/public-tunnel-live-chart
#   SKIP_TESTS=1 ./scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BRANCH="${1:-feature/public-tunnel-live-chart}"
SKIP_TESTS="${SKIP_TESTS:-0}"

# Read a single KEY=value from .env without `source` (values may contain spaces).
env_get() {
  local key="$1"
  local default="${2:-}"
  local file="${ROOT}/.env"
  if [[ ! -f "${file}" ]]; then
    printf '%s' "${default}"
    return 0
  fi
  local line
  line="$(grep -E "^${key}=" "${file}" | tail -n 1 || true)"
  if [[ -z "${line}" ]]; then
    printf '%s' "${default}"
    return 0
  fi
  local value="${line#*=}"
  value="${value%$'\r'}"
  if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
    value="${value:1:-1}"
  elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
    value="${value:1:-1}"
  fi
  printf '%s' "${value}"
}

POSTGRES_USER="$(env_get POSTGRES_USER statusgate)"
POSTGRES_PASSWORD="$(env_get POSTGRES_PASSWORD statusgate)"
POSTGRES_PORT="$(env_get POSTGRES_PORT 5432)"
JWT_SECRET="$(env_get JWT_SECRET deploy-check-jwt-secret-at-least-32-characters)"
TEST_DATABASE_URL="$(env_get TEST_DATABASE_URL "postgresql+psycopg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/statusgate_test")"

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
    -e "JWT_SECRET=${JWT_SECRET}" \
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
