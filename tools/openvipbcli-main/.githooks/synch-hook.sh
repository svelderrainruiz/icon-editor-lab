#!/usr/bin/env sh
# Insight Synch v2 – finished POSIX pre-commit hook (T + 15 d)

set -eu
EXTENSION_ID="labview-community.seed-insight"
GIT_ROOT=$(git rev-parse --show-toplevel)

# --- helper: semver ≥ compare ------------------------------------
check_ext() {          # $1 = minVersion
  min="$1"
  command -v code >/dev/null 2>&1 || return 0  # no CLI → skip
  ver=$(code --list-extensions --show-versions | awk -v id="$EXTENSION_ID" '$1==id{print $2}')
  [ -z "$ver" ] && return 1
  IFS=. read -r v1 v2 v3 <<EOF
$ver
EOF
  IFS=. read -r m1 m2 m3 <<EOF
$min
EOF
  [ "$v1" -gt "$m1" ] || { [ "$v1" -eq "$m1" ] && [ "$v2" -gt "$m2" ]; } ||
  { [ "$v1" -eq "$m1" ] && [ "$v2" -eq "$m2" ] && [ "$v3" -ge "$m3" ]; }
}

# --- staged insight files ----------------------------------------
FILES=$(git diff --cached --name-only | grep '\.insight\.json$' || true)
[ -z "$FILES" ] && exit 0

# --- fast lint + version check -----------------------------------
for f in $FILES; do
  # JSON lint via Node if available, else Python, else jq-like fallback
  if command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || {
      echo "JSON error in $f" >&2; exit 1; }
  elif command -v python >/dev/null 2>&1; then
    python - <<PY 2>/dev/null || { echo "JSON error in $f" >&2; exit 1; }
import json,sys; json.load(open("$f"))
PY
  fi

  # extract latest BEGIN/END block & minVersion
  minVer=$(awk '
    /BEGIN/{flag=1;blk="";next}
    /END/{if(flag){m=blk;flag=0}}
    flag{blk=blk"\n"$0}
    END{
      if(match(m,/"extensionMinVersion"[[:space:]]*:[[:space:]]*"([^"]+)"/,a))print a[1]; else print "0.0.0";
    }' "$f")
  if ! check_ext "$minVer"; then
    echo "VS Code extension $EXTENSION_ID ≥ $minVer required by $f" >&2
    exit 1
  fi
done

# --- deep validation ---------------------------------------------
"$GIT_ROOT/scripts/validate-insight.sh" $FILES
