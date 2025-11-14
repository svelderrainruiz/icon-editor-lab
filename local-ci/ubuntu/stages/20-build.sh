#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_SIGN_ROOT:?}"
: "${LOCALCI_REPO_ROOT:?}"

echo "Staging sample artifacts into $LOCALCI_SIGN_ROOT"

preserve_dirs=(local-signing-logs local-ci local-ci-ubuntu)
for path in "$LOCALCI_SIGN_ROOT"/* "$LOCALCI_SIGN_ROOT"/.*; do
  [[ -e "$path" ]] || continue
  name="$(basename "$path")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  skip=false
  for keep in "${preserve_dirs[@]}"; do
    if [[ "$name" == "$keep" ]]; then
      skip=true
      break
    fi
  done
  $skip && continue
  rm -rf "$path"
done

copy_payload() {
  local src="$LOCALCI_REPO_ROOT/$1"
  [[ -d "$src" ]] || return 0
  while IFS= read -r -d '' file; do
    rel="${file#$LOCALCI_REPO_ROOT/}"
    dest="$LOCALCI_SIGN_ROOT/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
  done < <(find "$src" -type f \( -name '*.ps1' -o -name '*.psm1' \) -print0)
}

copy_payload "tools"
copy_payload "scripts"

printf "Write-Output 'Sample payload for local CI build.'\n" > "$LOCALCI_SIGN_ROOT/Sample-Signed.ps1"
python3 - <<'PY' >"$LOCALCI_SIGN_ROOT/sample.exe"
import os
os.write(1, bytes(range(1,33)))
PY

count=$(find "$LOCALCI_SIGN_ROOT" -type f | wc -l)
echo "Build stage staged $count files."
