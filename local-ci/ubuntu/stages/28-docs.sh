#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"

CFG="$LOCALCI_REPO_ROOT/local-ci/ubuntu/config.yaml"
CHECK_LINKS=true
RUN_MARKDOWNLINT=true
ALLOW_MISSING=(
  "src/docs/ENVIRONMENT.md"
  "src/docs/vi-analyzer/README.md"
  "src/docs/DEV_DASHBOARD_PLAN.md"
  "src/docs/COMPARE_LOOP_MODULE.md"
  "src/docs/USAGE_GUIDE.md"
)

if [[ -f "$CFG" ]]; then
  eval "$(
    CFG_PATH="$CFG" python3 - <<'PY'
import os
import shlex

try:
    import yaml
except ModuleNotFoundError:
    yaml = None

cfg_path = os.environ.get("CFG_PATH")
if not cfg_path or not os.path.exists(cfg_path) or yaml is None:
    raise SystemExit(0)

with open(cfg_path, "r", encoding="utf-8") as handle:
    cfg = yaml.safe_load(handle) or {}

docs = cfg.get("docs_stage") or {}
print(f"CHECK_LINKS={'true' if docs.get('check_links', True) else 'false'}")
print(f"RUN_MARKDOWNLINT={'true' if docs.get('markdownlint', True) else 'false'}")

allow = list(docs.get("allow_missing", [])) + list(docs.get("allow_missing_globs", []))
for entry in allow:
    print('ALLOW_MISSING+=(' + shlex.quote(str(entry)) + ')')
PY
  )"
fi

if [[ "$CHECK_LINKS" != true && "$RUN_MARKDOWNLINT" != true ]]; then
  echo "[docs] Both link check and markdownlint disabled; skipping stage."
  exit 0
fi

pushd "$LOCALCI_REPO_ROOT" >/dev/null

if [[ "$CHECK_LINKS" == true ]]; then
  echo "[docs] Checking local markdown links"
  ALLOW_SERIALIZED=""
  if [[ ${#ALLOW_MISSING[@]} -gt 0 ]]; then
    printf -v ALLOW_SERIALIZED '%s\n' "${ALLOW_MISSING[@]}"
  fi
  LOCALCI_DOC_ALLOWLIST="$ALLOW_SERIALIZED" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["LOCALCI_REPO_ROOT"]).resolve()
allow_patterns = [line.strip() for line in os.environ.get("LOCALCI_DOC_ALLOWLIST", "").splitlines() if line.strip()]
skip_dirs = {'node_modules','vendor','.git','bin','dist','build','coverage','out'}
link_pattern = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
inline_pattern = re.compile(r"`[^`]+`")
fence_markers = ("```", "~~~")
errors = []

for path in root.rglob('*.md'):
    if any(part in skip_dirs for part in path.parts):
        continue
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except OSError:
        continue
    in_fence = False
    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if stripped.startswith(fence_markers):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = inline_pattern.sub('', raw_line)
        for target in link_pattern.findall(line):
            target = target.strip()
            if not target or target.startswith(('http://','https://','mailto:','#')):
                continue
            rel = target.split('#',1)[0]
            candidate = (path.parent / rel).resolve()
            try:
                rel_norm = candidate.relative_to(root).as_posix()
            except ValueError:
                rel_norm = rel
            if candidate.exists():
                continue
            if any(rel_norm == pat or Path(rel_norm).match(pat) for pat in allow_patterns):
                continue
            errors.append(f"{path.relative_to(root)} -> {target}")

if errors:
    print("[docs] Broken local links detected:")
    for entry in errors:
        print(f"  - {entry}")
    sys.exit(1)
else:
    print("[docs] Local link check passed")
PY
fi

if [[ "$RUN_MARKDOWNLINT" == true ]]; then
  echo "[docs] Running markdownlint"
  docker run --rm -v "$LOCALCI_REPO_ROOT:/work" -w /work node:20-alpine sh -c "npm install -g markdownlint-cli && markdownlint \"**/*.md\" --config .markdownlint.jsonc --ignore node_modules --ignore bin --ignore vendor"
fi

popd >/dev/null
