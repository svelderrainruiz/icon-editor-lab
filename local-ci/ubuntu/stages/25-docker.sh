#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"

DOCKERFILE="$LOCALCI_REPO_ROOT/src/tools/docker/Dockerfile.tools"
IMAGE_TAG="${LOCALCI_DOCKER_IMAGE_TAG:-icon-editor-lab/tools:local-ci}"
REMOTE_IMAGE="${LOCALCI_DOCKER_REMOTE_IMAGE:-ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci}"
PULL_REMOTE="${LOCALCI_DOCKER_PULL_REMOTE:-true}"
PUSH_REMOTE="${LOCALCI_DOCKER_PUSH_REMOTE:-false}"
USE_BUILDX="${LOCALCI_DOCKER_USE_BUILDX:-false}"
SKIP_PREFLIGHT="${LOCALCI_DOCKER_SKIP_PREFLIGHT:-false}"

# Derive a default cache ref from the remote image if not provided: replace tag with :buildcache
if [[ -z "${LOCALCI_DOCKER_CACHE_REF:-}" ]]; then
  # strip any @digest first
  base_ref="${REMOTE_IMAGE%%@*}"
  # ensure we have a :tag portion; if not, append :latest
  if [[ "$base_ref" != *:* ]]; then
    base_ref="$base_ref:latest"
  fi
  repo_part="${base_ref%:*}"
  CACHE_REF="$repo_part:buildcache"
else
  CACHE_REF="$LOCALCI_DOCKER_CACHE_REF"
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Dockerfile not found at $DOCKERFILE" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found; install Docker Desktop/Engine to run this stage." >&2
  exit 1
fi

preflight_ok=true
if [[ "$SKIP_PREFLIGHT" != "true" ]]; then
  if command -v curl >/dev/null 2>&1; then
    echo "Performing GHCR preflight check..."
    code=$(curl -fsS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 -I https://ghcr.io/v2/ || true)
    if [[ -z "$code" || "$code" -ge 500 ]]; then
      echo "Warning: GHCR preflight indicates network issues (http=$code). Push/cache operations may fail." >&2
      preflight_ok=false
    fi
  else
    echo "curl not available; skipping GHCR preflight."
  fi
fi

cache_from=()
if [[ "$PULL_REMOTE" == "true" ]]; then
  echo "Attempting to pull remote cache image '$REMOTE_IMAGE'"
  if docker pull "$REMOTE_IMAGE" >/dev/null 2>&1; then
    cache_from+=(--cache-from "$REMOTE_IMAGE")
    echo "Successfully pulled $REMOTE_IMAGE; will reuse layers"
  else
    echo "Remote image $REMOTE_IMAGE not available; proceeding without cache."
  fi
fi

if [[ "$USE_BUILDX" == "true" ]] && docker buildx version >/dev/null 2>&1; then
  echo "Building (buildx) Docker image '$IMAGE_TAG' from $DOCKERFILE"
  # Ensure a usable builder exists; use default if present
  if ! docker buildx ls >/dev/null 2>&1; then
    echo "buildx not fully initialized; falling back to docker build"
    USE_BUILDX="false"
  fi
fi

if [[ "$USE_BUILDX" == "true" ]]; then
  # Try to use registry cache if preflight succeeded
  bx_args=(--file "$DOCKERFILE" --tag "$IMAGE_TAG" --load "$LOCALCI_REPO_ROOT")
  if [[ "$preflight_ok" == "true" ]]; then
    bx_args+=(--cache-from "type=registry,ref=$CACHE_REF" --cache-to "type=registry,ref=$CACHE_REF,mode=max")
    echo "Using buildx registry cache: $CACHE_REF"
  fi
  docker buildx build "${bx_args[@]}"
else
  echo "Building Docker image '$IMAGE_TAG' from $DOCKERFILE"
  docker build --file "$DOCKERFILE" --tag "$IMAGE_TAG" "${cache_from[@]}" "$LOCALCI_REPO_ROOT"
fi

if [[ "$PUSH_REMOTE" == "true" ]]; then
  echo "Preparing to push $IMAGE_TAG to $REMOTE_IMAGE with retries"
  HELPER="$LOCALCI_REPO_ROOT/local-ci/ubuntu/scripts/push-docker-cache.sh"
  if [[ -x "$HELPER" ]]; then
    LOCALCI_DOCKER_IMAGE_TAG="$IMAGE_TAG" \
    LOCALCI_DOCKER_REMOTE_IMAGE="$REMOTE_IMAGE" \
    bash "$HELPER"
  else
    echo "Helper $HELPER missing; falling back to direct docker push"
    docker tag "$IMAGE_TAG" "$REMOTE_IMAGE"
    docker push "$REMOTE_IMAGE"
  fi
fi

echo "Validating tool image '$IMAGE_TAG' can execute core CLIs"
docker run --rm "$IMAGE_TAG" bash -lc "set -euo pipefail; node --version; pwsh -NoLogo -NoProfile -Command '\$PSVersionTable.PSVersion'; python3 --version"
