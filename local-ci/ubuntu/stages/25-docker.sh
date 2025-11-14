#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"

DOCKERFILE="$LOCALCI_REPO_ROOT/src/tools/docker/Dockerfile.tools"
IMAGE_TAG="${LOCALCI_DOCKER_IMAGE_TAG:-icon-editor-lab/tools:local-ci}"
UBUNTU_RUNNER_IMAGE_TAG="${LOCALCI_UBUNTU_RUNNER_IMAGE_TAG:-icon-editor-lab/ubuntu-runner:local-ci}"
REMOTE_IMAGE="${LOCALCI_DOCKER_REMOTE_IMAGE:-ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci}"
UBUNTU_RUNNER_REMOTE_IMAGE="${LOCALCI_UBUNTU_RUNNER_REMOTE_IMAGE:-ghcr.io/svelderrainruiz/icon-editor-lab/ubuntu-runner:local-ci}"
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

required_sources=(
  "$LOCALCI_REPO_ROOT/Directory.Build.props"
  "$LOCALCI_REPO_ROOT/src/CompareVi.Shared/CompareVi.Shared.csproj"
  "$LOCALCI_REPO_ROOT/src/CompareVi.Tools.Cli/CompareVi.Tools.Cli.csproj"
)
missing_sources=()
for src_path in "${required_sources[@]}"; do
  if [[ ! -f "$src_path" ]]; then
    missing_sources+=("$src_path")
  fi
done
if [[ ${#missing_sources[@]} -gt 0 ]]; then
  echo "[25-docker] Required source files are unavailable; skipping Docker build."
  for missing in "${missing_sources[@]}"; do
    echo "  - missing: $missing"
  done
  echo "[25-docker] Provide CompareVi projects before enabling this stage."
  exit 0
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
remote_cache_available=false
if [[ "$PULL_REMOTE" == "true" ]]; then
  echo "Attempting to pull remote cache image '$REMOTE_IMAGE'"
  if docker pull "$REMOTE_IMAGE" >/dev/null 2>&1; then
    cache_from+=(--cache-from "$REMOTE_IMAGE")
    echo "Successfully pulled $REMOTE_IMAGE; will reuse layers"
    remote_cache_available=true
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
  build_context="$LOCALCI_REPO_ROOT"
  bx_args=(docker buildx build --file "$DOCKERFILE" --tag "$IMAGE_TAG" --load)
  if [[ "$preflight_ok" == "true" ]]; then
    bx_args+=(--cache-from "type=registry,ref=$CACHE_REF")
    bx_args+=(--cache-to "type=registry,ref=$CACHE_REF,mode=max")
    if [[ "$remote_cache_available" == "true" ]]; then
      echo "Using buildx registry cache: $CACHE_REF"
    else
      echo "Registry reachable; enabling cache namespace $CACHE_REF"
    fi
  else
    local_cache_dir="$LOCALCI_REPO_ROOT/.docker-cache/tools"
    mkdir -p "$local_cache_dir"
    bx_args+=(--cache-from "type=local,src=$local_cache_dir")
    bx_args+=(--cache-to "type=local,dest=$local_cache_dir,mode=max")
    echo "Registry cache unavailable; using local cache dir $local_cache_dir"
  fi
  bx_args+=("$build_context")
  "${bx_args[@]}"
else
  echo "Building Docker image '$IMAGE_TAG' from $DOCKERFILE"
  docker build --file "$DOCKERFILE" --tag "$IMAGE_TAG" "${cache_from[@]}" "$LOCALCI_REPO_ROOT"
fi

echo "Building Ubuntu runner image '$UBUNTU_RUNNER_IMAGE_TAG' from $DOCKERFILE"
if [[ "$USE_BUILDX" == "true" ]]; then
  build_context="$LOCALCI_REPO_ROOT"
  bx_handshake=(docker buildx build --file "$DOCKERFILE" --target ubuntu-runner --tag "$UBUNTU_RUNNER_IMAGE_TAG" --load)
  if [[ "$preflight_ok" == "true" ]]; then
    bx_handshake+=(--cache-from "type=registry,ref=$CACHE_REF")
    bx_handshake+=(--cache-to "type=registry,ref=$CACHE_REF,mode=max")
  else
    local_cache_dir="$LOCALCI_REPO_ROOT/.docker-cache/tools"
    mkdir -p "$local_cache_dir"
    bx_handshake+=(--cache-from "type=local,src=$local_cache_dir")
    bx_handshake+=(--cache-to "type=local,dest=$local_cache_dir,mode=max")
  fi
  bx_handshake+=("$build_context")
  "${bx_handshake[@]}"
else
  docker build --file "$DOCKERFILE" --target ubuntu-runner --tag "$UBUNTU_RUNNER_IMAGE_TAG" "${cache_from[@]}" "$LOCALCI_REPO_ROOT"
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
  echo "Pushing Ubuntu runner image to $UBUNTU_RUNNER_REMOTE_IMAGE"
  docker tag "$UBUNTU_RUNNER_IMAGE_TAG" "$UBUNTU_RUNNER_REMOTE_IMAGE"
  docker push "$UBUNTU_RUNNER_REMOTE_IMAGE"
fi

echo "Validating tool image '$IMAGE_TAG' can execute core CLIs"
docker run --rm "$IMAGE_TAG" bash -lc "set -euo pipefail; node --version; pwsh -NoLogo -NoProfile -Command '\$PSVersionTable.PSVersion'; python3 --version"
echo "Running tooling intent checks inside image"
docker run --rm -v "$LOCALCI_REPO_ROOT:/work:ro" "$IMAGE_TAG" pwsh -NoLogo -NoProfile -File /opt/local-ci/Test-ToolingIntent.ps1 -RepoRoot /work
echo "Validating Ubuntu runner entrypoint"
docker run --rm -v "$LOCALCI_REPO_ROOT:/work:ro" "$UBUNTU_RUNNER_IMAGE_TAG" --list >/dev/null
