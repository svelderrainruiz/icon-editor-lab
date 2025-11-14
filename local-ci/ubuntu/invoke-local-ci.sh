#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.yaml}"

SIGN_ROOT="out"
PESTER_TAGS=("smoke" "linux")
SKIP_STAGES_DEFAULT=()

if [[ -f "$CONFIG_FILE" ]]; then
  current=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      sign_root:*)
        SIGN_ROOT="$(printf '%s' "$line" | cut -d':' -f2- | xargs)"
        ;;
      pester_tags:*)
        current="pester"
        PESTER_TAGS=()
        ;;
      skip_stages:*)
        current="skip"
        SKIP_STAGES_DEFAULT=()
        ;;
      '  -'*)
        value="$(printf '%s' "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')"
        if [[ -n "$value" ]]; then
          if [[ "$current" == "pester" ]]; then
            PESTER_TAGS+=("$value")
          elif [[ "$current" == "skip" ]]; then
            SKIP_STAGES_DEFAULT+=("$value")
          fi
        fi
        ;;
    esac
  done < "$CONFIG_FILE"
fi

ONLY_STAGES=()
SKIP_STAGES=("${SKIP_STAGES_DEFAULT[@]}")
LIST_STAGES=0

usage() {
  cat <<'EOF'
Usage: invoke-local-ci.sh [options]
  --only <stage>   Run only the specified stage id (e.g., 10,20) or name.
  --skip <stage>   Skip the specified stage id or name.
  --list           List stages and exit.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      shift
      [[ $# -gt 0 ]] || { echo "--only requires a value" >&2; exit 1; }
      ONLY_STAGES+=("$1")
      ;;
    --skip)
      shift
      [[ $# -gt 0 ]] || { echo "--skip requires a value" >&2; exit 1; }
      SKIP_STAGES+=("$1")
      ;;
    --list)
      LIST_STAGES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

STAGES=(
  "10-prep"
  "20-build"
  "25-docker"
  "28-docs"
  "30-tests"
  "35-coverage"
  "45-vi-compare"
  "40-package"
)

DELIM=$'\x1f'
STAGE_RECORDS=()

if [[ $LIST_STAGES -eq 1 ]]; then
  printf "Defined stages:\n"
  for stage in "${STAGES[@]}"; do
    printf "  %s\n" "$stage"
  done
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
SIGN_ROOT_ABS="$REPO_ROOT/$SIGN_ROOT"
RUN_ROOT="$REPO_ROOT/out/local-ci-ubuntu/$timestamp"
mkdir -p "$SIGN_ROOT_ABS" "$RUN_ROOT"

record_stage() {
  local name="$1"
  local status="$2"
  local log="$3"
  local duration="$4"
  local id="${name%%-*}"
  STAGE_RECORDS+=("${name}${DELIM}${status}${DELIM}${log}${DELIM}${duration}${DELIM}${id}")
}

write_manifest() {
  local manifest_path="$RUN_ROOT/ubuntu-run.json"
  local stage_file="$RUN_ROOT/.stage-records"
  : > "$stage_file"
  if [[ ${#STAGE_RECORDS[@]} -gt 0 ]]; then
    printf "%s\n" "${STAGE_RECORDS[@]}" >> "$stage_file"
  fi
  local git_commit
  git_commit="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')"
  local git_branch
  git_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
  local artifact_rel="out/local-ci-ubuntu/$timestamp/local-ci-artifacts.zip"
  local artifact_abs="$RUN_ROOT/local-ci-artifacts.zip"
  if [[ ! -f "$artifact_abs" ]]; then
    artifact_rel=""
    artifact_abs=""
  fi
  local coverage_xml="$REPO_ROOT/out/coverage/coverage.xml"
  if [[ ! -f "$coverage_xml" ]]; then
    coverage_xml=""
  fi
  LOCALCI_MANIFEST_PATH="$manifest_path" \
  LOCALCI_STAGE_FILE="$stage_file" \
  LOCALCI_REPO_ROOT="$REPO_ROOT" \
  LOCALCI_RUN_ROOT="$RUN_ROOT" \
  LOCALCI_SIGN_ROOT="$SIGN_ROOT_ABS" \
  LOCALCI_TIMESTAMP="$timestamp" \
  LOCALCI_GIT_COMMIT="$git_commit" \
  LOCALCI_GIT_BRANCH="$git_branch" \
  LOCALCI_ARTIFACT_REL="$artifact_rel" \
  LOCALCI_ARTIFACT_ABS="$artifact_abs" \
  LOCALCI_COVERAGE_XML="$coverage_xml" \
  LOCALCI_CONFIG_PATH="$CONFIG_FILE" \
  LOCALCI_DELIM="$DELIM" \
  python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path
try:
    import yaml  # type: ignore
except ModuleNotFoundError:
    yaml = None

manifest_path = Path(os.environ["LOCALCI_MANIFEST_PATH"])
stage_file = Path(os.environ["LOCALCI_STAGE_FILE"])
repo_root = Path(os.environ["LOCALCI_REPO_ROOT"])
run_root = Path(os.environ["LOCALCI_RUN_ROOT"])
sign_root = Path(os.environ["LOCALCI_SIGN_ROOT"])
timestamp = os.environ["LOCALCI_TIMESTAMP"]
git_commit = os.environ["LOCALCI_GIT_COMMIT"]
git_branch = os.environ["LOCALCI_GIT_BRANCH"]
artifact_rel = os.environ.get("LOCALCI_ARTIFACT_REL") or None
artifact_abs = os.environ.get("LOCALCI_ARTIFACT_ABS") or None
coverage_xml = os.environ.get("LOCALCI_COVERAGE_XML") or None
cfg_path = os.environ.get("LOCALCI_CONFIG_PATH") or ""
delim = os.environ.get("LOCALCI_DELIM", "\x1f")

coverage_min = 75
if cfg_path and os.path.exists(cfg_path) and yaml is not None:
    try:
        with open(cfg_path, "r", encoding="utf-8") as handle:
            cfg = yaml.safe_load(handle) or {}
        coverage_min = int((cfg.get("coverage") or {}).get("min_percent", coverage_min))
    except Exception:
        pass

coverage_percent = None
coverage_rel = None
if coverage_xml:
    try:
        from xml.etree import ElementTree as ET
        coverage_path = Path(coverage_xml)
        if coverage_path.is_file():
            root = ET.parse(coverage_path).getroot()
            total = covered = 0
            for line in root.findall('.//class//line'):
                total += 1
                hits = int(line.get('hits', '0'))
                if hits > 0:
                    covered += 1
            if total:
                coverage_percent = round(covered / total * 100, 2)
            coverage_rel = coverage_path.relative_to(repo_root).as_posix()
    except Exception:
        coverage_percent = None
        coverage_rel = None

stages = []
if stage_file.exists():
    for raw in stage_file.read_text(encoding='utf-8').splitlines():
        if not raw.strip():
            continue
        parts = raw.split(delim)
        if len(parts) < 5:
            continue
        name, status, log_path, duration, stage_id = parts[:5]
        log_rel = None
        log_abs = Path(log_path)
        if log_abs.exists():
            try:
                log_rel = log_abs.relative_to(repo_root).as_posix()
            except ValueError:
                log_rel = log_abs.as_posix()
        stages.append({
            "id": stage_id,
            "name": name,
            "status": status,
            "log": log_rel or log_abs.as_posix(),
            "duration_seconds": int(duration)
        })

manifest = {
    "runner": "ubuntu",
    "timestamp": timestamp,
    "created_at_utc": datetime.now(timezone.utc).isoformat(),
    "git": {
        "commit": git_commit,
        "branch": git_branch
    },
    "paths": {
        "repo_root": repo_root.as_posix(),
        "run_root": run_root.as_posix(),
        "sign_root": sign_root.as_posix(),
        "artifact_zip_rel": artifact_rel,
        "artifact_zip_abs": artifact_abs,
        "coverage_xml_rel": coverage_rel
    },
    "coverage": {
        "percent": coverage_percent,
        "min_percent": coverage_min
    } if coverage_percent is not None else None,
    "stages": stages
}

  manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
  print(f"[local-ci] Wrote Ubuntu manifest to {manifest_path}")
PY
  rm -f "$stage_file"

  LOCALCI_POINTER_PATH="$REPO_ROOT/out/local-ci-ubuntu/latest.json" \
  LOCALCI_RUN_ROOT="$RUN_ROOT" \
  LOCALCI_TIMESTAMP="$timestamp" \
  python3 - <<'PY'
import json
import os
from datetime import datetime, timezone

pointer_path = os.environ["LOCALCI_POINTER_PATH"]
run_root = os.environ["LOCALCI_RUN_ROOT"]
timestamp = os.environ["LOCALCI_TIMESTAMP"]
manifest_path = os.path.join(run_root, "ubuntu-run.json")
manifest_rel = os.path.join("out", "local-ci-ubuntu", timestamp, "ubuntu-run.json").replace("\\", "/")
payload = {
    "timestamp": timestamp,
    "updated_at_utc": datetime.now(timezone.utc).isoformat(),
    "manifest": manifest_path,
    "manifest_rel": manifest_rel,
    "run_root": run_root,
}
pointer_dir = os.path.dirname(pointer_path)
os.makedirs(pointer_dir, exist_ok=True)
tmp_path = f"{pointer_path}.tmp"
with open(tmp_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
os.replace(tmp_path, pointer_path)
print(f"[local-ci] Updated latest Ubuntu manifest pointer -> {pointer_path}")
PY
}

mark_run_ready() {
  local ready_file="$RUN_ROOT/_READY"
  local done_file="$RUN_ROOT/_DONE"
  local claim_file="$RUN_ROOT/windows.claimed"
  rm -f "$ready_file" "$done_file" "$claim_file"
  local stamp
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"state":"ready","created_at_utc":"%s"}\n' "$stamp" > "$ready_file"
  echo "[local-ci] Marked run ready at $ready_file"
}

run_stage() {
  local stage="$1"
  local stage_file="$SCRIPT_DIR/stages/${stage}.sh"
  if [[ ! -x "$stage_file" ]]; then
    echo "Stage script $stage_file missing or not executable" >&2
    exit 1
  fi

  local log_file="$RUN_ROOT/${stage}.log"
  echo "==> Stage $stage"
  local status="succeeded"
  local start_time
  local end_time
  start_time=$(date +%s)
  if (
    set -euo pipefail
    export LOCALCI_SIGN_ROOT="$SIGN_ROOT_ABS"
    export LOCALCI_RUN_ROOT="$RUN_ROOT"
    export LOCALCI_REPO_ROOT="$REPO_ROOT"
    export LOCALCI_PESTER_TAGS="${PESTER_TAGS[*]}"
    export LOCALCI_STAGE_NAME="$stage"
    bash "$stage_file"
  ) > >(tee "$log_file") 2>&1; then
    status="succeeded"
  else
    status="failed"
  fi
  end_time=$(date +%s)
  local duration=$((end_time - start_time))
  echo "    log: $log_file"
  record_stage "$stage" "$status" "$log_file" "$duration"
  if [[ "$status" != "succeeded" ]]; then
    echo "Stage $stage failed; aborting run." >&2
    exit 1
  fi
}

should_run() {
  local stage="$1"
  local id="${stage%%-*}"
  for val in "${SKIP_STAGES[@]}"; do
    if [[ "$val" == "$stage" || "$val" == "$id" ]]; then
      return 1
    fi
  done
  if [[ ${#ONLY_STAGES[@]} -gt 0 ]]; then
    local ok=1
    for val in "${ONLY_STAGES[@]}"; do
      if [[ "$val" == "$stage" || "$val" == "$id" ]]; then
        ok=0
        break
      fi
    done
    if [[ $ok -ne 0 ]]; then
      return 1
    fi
  fi
  return 0
}

for stage in "${STAGES[@]}"; do
  if should_run "$stage"; then
    run_stage "$stage"
  else
    echo "-- Skipping stage $stage"
  fi
done

write_manifest
mark_run_ready

echo "Local Ubuntu CI run complete. Logs: $RUN_ROOT"
