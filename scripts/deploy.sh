#!/usr/bin/env bash
# Optional wrapper around the compose-native test + deploy flow.
# Prefer the README compose commands if you already use docker compose directly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BRANCH="${1:-feature/public-tunnel-live-chart}"
SKIP_TESTS="${SKIP_TESTS:-0}"

echo "==> Pull ${BRANCH}"
git pull --ff-only "origin" "${BRANCH}"
git submodule update --init --recursive

echo "==> Ensure Postgres is up"
docker compose up -d db

if [[ "${SKIP_TESTS}" != "1" ]]; then
  echo "==> Backend tests"
  docker compose --profile test run --rm backend-test
else
  echo "==> SKIP_TESTS=1 — skipping backend-test"
fi

echo "==> Rebuild and restart (frontend image runs npm test during build unless RUN_TESTS=0)"
docker compose up -d --build frontend backend worker

echo "==> Done"
docker compose ps
