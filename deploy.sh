#!/usr/bin/env bash
# Deploy StatusGate: pull latest code (including submodules) and rebuild containers.
# Usage: ./deploy.sh [service...]   e.g. ./deploy.sh frontend
set -euo pipefail
cd "$(dirname "$0")"

TOTAL=5
STEP=0

step() {
  STEP=$((STEP + 1))
  echo
  echo "==> [$STEP/$TOTAL] $1"
}

step "Pulling latest code"
git pull --ff-only
echo "    repo at $(git rev-parse --short HEAD)"

step "Updating submodules (backend, frontend)"
git submodule update --init --recursive
git submodule status

step "Resolving frontend build version"
# The frontend Docker context has no .git (submodule), so the commit SHA
# for the footer version label must be passed in as a build arg.
FRONTEND_GIT_SHA="$(git -C frontend rev-parse --short HEAD)"
export FRONTEND_GIT_SHA
echo "    frontend SHA: $FRONTEND_GIT_SHA"

step "Building and starting containers${*:+: $*}"
docker compose up -d --build "$@"

step "Checking container status"
docker compose ps

echo
echo "==> Deploy finished."
