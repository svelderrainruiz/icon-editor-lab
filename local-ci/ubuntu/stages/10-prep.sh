#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_SIGN_ROOT:?LOCALCI_SIGN_ROOT not set}"
: "${LOCALCI_RUN_ROOT:?LOCALCI_RUN_ROOT not set}"
: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"

echo "Sign root : $LOCALCI_SIGN_ROOT"
echo "Run root  : $LOCALCI_RUN_ROOT"

mkdir -p "$LOCALCI_SIGN_ROOT" "$LOCALCI_RUN_ROOT"

preserve_dirs=(local-signing-logs local-ci local-ci-ubuntu)
for dir in "${preserve_dirs[@]}"; do
  mkdir -p "$LOCALCI_SIGN_ROOT/$dir"
done

git_status_file="$LOCALCI_RUN_ROOT/git-status.txt"
if command -v git >/dev/null 2>&1; then
  git -C "$LOCALCI_REPO_ROOT" status --short > "$git_status_file" || true
else
  printf 'git not found; skipped status snapshot\n' > "$git_status_file"
fi
