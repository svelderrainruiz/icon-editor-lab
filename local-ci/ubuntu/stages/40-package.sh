#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_SIGN_ROOT:?}"
: "${LOCALCI_RUN_ROOT:?}"
: "${LOCALCI_REPO_ROOT:?}"

HASH_SCRIPT="$LOCALCI_REPO_ROOT/tools/Hash-Artifacts.ps1"
if [[ ! -f "$HASH_SCRIPT" ]]; then
  echo "Hash script $HASH_SCRIPT not found" >&2
  exit 1
fi

if [[ -z "$(find "$LOCALCI_SIGN_ROOT" -type f -print -quit)" ]]; then
  echo "No artifacts under $LOCALCI_SIGN_ROOT, skipping package."
  exit 0
fi

preserve_dirs=(local-signing-logs local-ci local-ci-ubuntu)
pack_root="$LOCALCI_RUN_ROOT/pack-root"
rm -rf "$pack_root"
mkdir -p "$pack_root"

for entry in "$LOCALCI_SIGN_ROOT"/* "$LOCALCI_SIGN_ROOT"/.*; do
  [[ -e "$entry" ]] || continue
  name="$(basename "$entry")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  skip=false
  for keep in "${preserve_dirs[@]}"; do
    if [[ "$name" == "$keep" ]]; then
      skip=true
      break
    fi
  done
  $skip && continue
  dest="$pack_root/$name"
  if [[ -d "$entry" ]]; then
    cp -R "$entry" "$dest"
  else
    cp "$entry" "$dest"
  fi
done

pwsh -NoLogo -NoProfile -File "$HASH_SCRIPT" -Root "$pack_root" -Output checksums.sha256
zip_path="$LOCALCI_RUN_ROOT/local-ci-artifacts.zip"
rm -f "$zip_path"
if command -v zip >/dev/null 2>&1; then
  (cd "$pack_root" && zip -r "$zip_path" . >/dev/null)
else
  echo "zip CLI not found; using python3 zipfile fallback."
  python3 - <<PY
import os, sys, zipfile
pack_root = os.path.abspath("$pack_root")
zip_path = os.path.abspath("$zip_path")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(pack_root):
        for name in files:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, pack_root)
            zf.write(full, rel)
PY
fi
echo "Packaged artifacts into $zip_path"
rm -rf "$pack_root"
