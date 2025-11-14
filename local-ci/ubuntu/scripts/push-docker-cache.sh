#!/usr/bin/env bash
set -euo pipefail

# Pushes a Docker image to a remote registry with retries and backoff.
# Env:
#   LOCALCI_DOCKER_IMAGE_TAG     Local image tag to push (default: icon-editor-lab/tools:local-ci)
#   LOCALCI_DOCKER_REMOTE_IMAGE  Remote image ref (default: ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci)
#   LOCALCI_DOCKER_PUSH_ATTEMPTS Number of push attempts (default: 5)
#   LOCALCI_DOCKER_PUSH_BACKOFF  Initial backoff seconds (default: 2)

LOCAL_IMAGE="${LOCALCI_DOCKER_IMAGE_TAG:-icon-editor-lab/tools:local-ci}"
REMOTE_IMAGE="${LOCALCI_DOCKER_REMOTE_IMAGE:-ghcr.io/svelderrainruiz/icon-editor-lab/tools:local-ci}"
ATTEMPTS="${LOCALCI_DOCKER_PUSH_ATTEMPTS:-5}"
BACKOFF="${LOCALCI_DOCKER_PUSH_BACKOFF:-2}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found; install Docker Desktop/Engine before pushing." >&2
  exit 1
fi

# Optional GHCR preflight
if command -v curl >/dev/null 2>&1; then
  code=$(curl -fsS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 -I https://ghcr.io/v2/ || true)
  if [[ -z "$code" || "$code" -ge 500 ]]; then
    echo "[push] Warning: GHCR preflight indicates network issues (http=$code). Push may fail quickly." >&2
  fi
fi

echo "Tagging ${LOCAL_IMAGE} -> ${REMOTE_IMAGE}"
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"

try=1
while [[ $try -le $ATTEMPTS ]]; do
  echo "[push] Attempt $try/$ATTEMPTS: docker push $REMOTE_IMAGE"
  if docker push "$REMOTE_IMAGE"; then
    echo "[push] Successfully pushed $REMOTE_IMAGE"
    # Optional verification (best-effort)
    if docker manifest inspect "$REMOTE_IMAGE" >/dev/null 2>&1; then
      echo "[push] Verified manifest available for $REMOTE_IMAGE"
    fi
    exit 0
  fi
  if [[ $try -lt $ATTEMPTS ]]; then
    echo "[push] Push failed; backing off for ${BACKOFF}s before retry..."
    sleep "$BACKOFF"
    BACKOFF=$(( BACKOFF * 2 ))
  fi
  try=$(( try + 1 ))
done

echo "[push] Exhausted retries pushing $REMOTE_IMAGE" >&2
exit 1
