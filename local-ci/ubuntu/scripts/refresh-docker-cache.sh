#!/usr/bin/env bash
set -euo pipefail

REMOTE_IMAGE="${LOCALCI_DOCKER_REMOTE_IMAGE:-ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci}"
# Also try the buildx cache ref when present
if [[ -n "${LOCALCI_DOCKER_CACHE_REF:-}" ]]; then
  CACHE_REF="$LOCALCI_DOCKER_CACHE_REF"
else
  base_ref="${REMOTE_IMAGE%%@*}"
  [[ "$base_ref" != *:* ]] && base_ref="$base_ref:latest"
  repo_part="${base_ref%:*}"
  CACHE_REF="$repo_part:buildcache"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found; install Docker Desktop/Engine before refreshing cache." >&2
  exit 1
fi

echo "Pulling cache image $REMOTE_IMAGE"
if docker pull "$REMOTE_IMAGE"; then
  echo "Cache image $REMOTE_IMAGE pulled successfully."
else
  echo "Existing cache image $REMOTE_IMAGE not available yet."
fi

echo "Pulling buildx cache ref $CACHE_REF"
if docker pull "$CACHE_REF" >/dev/null 2>&1; then
  echo "Buildx cache $CACHE_REF pulled successfully."
else
  echo "Buildx cache $CACHE_REF not available yet."
fi
