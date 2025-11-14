#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${LOCALCI_REPO_ROOT:-/work}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "[ubuntu-runner] Repo root '$REPO_ROOT' not found." >&2
  exit 1
fi
if [[ ! -d "$REPO_ROOT/local-ci/ubuntu" ]]; then
  echo "[ubuntu-runner] local-ci scripts not found under $REPO_ROOT/local-ci/ubuntu" >&2
  exit 1
fi
cd "$REPO_ROOT"
if [[ $# -eq 0 ]]; then
  echo "Usage: localci-run-handshake [invoke-local-ci.sh options]" >&2
  echo "Example: localci-run-handshake --skip 28-docs --skip 30-tests" >&2
  exit 1
fi
export LOCALCI_REPO_ROOT="$REPO_ROOT"
exec bash local-ci/ubuntu/invoke-local-ci.sh "$@"
