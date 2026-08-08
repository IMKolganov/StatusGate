#!/usr/bin/env bash
# Pull latest code (including submodules) and rebuild containers.
# Usage: ./deploy.sh [service...]   e.g. ./deploy.sh frontend
set -euo pipefail
cd "$(dirname "$0")"

git pull --ff-only
git submodule update --init --recursive

# The frontend Docker context has no .git (submodule), so the commit SHA
# for the footer version label must be passed in as a build arg.
FRONTEND_GIT_SHA="$(git -C frontend rev-parse --short HEAD)"
export FRONTEND_GIT_SHA

docker compose up -d --build "$@"
docker compose ps
