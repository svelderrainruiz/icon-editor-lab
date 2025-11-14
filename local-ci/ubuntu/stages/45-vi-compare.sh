#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"
: "${LOCALCI_RUN_ROOT:?LOCALCI_RUN_ROOT not set}"

CFG_FILE="$LOCALCI_REPO_ROOT/local-ci/ubuntu/config.yaml"
VI_ENABLED=true
VI_DRY_RUN=true
VI_REQUESTS_TEMPLATE=""
WINDOWS_PUBLISH_ROOT=""

parse_vi_config() {
  python3 - <<'PY' "$CFG_FILE"
import os, sys, json
try:
    import yaml
except ModuleNotFoundError:
    yaml = None

cfg_path = sys.argv[1]
if not os.path.exists(cfg_path) or yaml is None:
    sys.exit(0)
with open(cfg_path, "r", encoding="utf-8") as handle:
    cfg = yaml.safe_load(handle) or {}
vi = cfg.get("vi_compare") or {}
print(json.dumps({
    "enabled": bool(vi.get("enabled", True)),
    "dry_run": bool(vi.get("dry_run", True)),
    "template": (vi.get("requests_template") or "").strip(),
    "publish_root": (vi.get("windows_publish_root") or "").strip(),
}))
PY
}

if [[ -f "$CFG_FILE" ]]; then
  cfg_json="$(parse_vi_config)"
  if [[ -n "$cfg_json" ]]; then
    VI_ENABLED=$(python3 - <<'PY' "$cfg_json"
import sys, json
cfg=json.loads(sys.argv[1])
print('true' if cfg.get('enabled', True) else 'false')
PY
)
    VI_DRY_RUN=$(python3 - <<'PY' "$cfg_json"
import sys, json
cfg=json.loads(sys.argv[1])
print('true' if cfg.get('dry_run', True) else 'false')
PY
)
    VI_REQUESTS_TEMPLATE=$(python3 - <<'PY' "$cfg_json"
import sys, json
cfg=json.loads(sys.argv[1])
print(cfg.get('template',''))
PY
)
    WINDOWS_PUBLISH_ROOT=$(python3 - <<'PY' "$cfg_json"
import sys, json
cfg=json.loads(sys.argv[1])
print(cfg.get('publish_root',''))
PY
)
  fi
fi

if [[ "$VI_ENABLED" != "true" ]]; then
  echo "[vi-compare] Disabled via config; skipping stage."
  exit 0
fi

if [[ -z "$WINDOWS_PUBLISH_ROOT" ]]; then
  WINDOWS_PUBLISH_ROOT="$LOCALCI_REPO_ROOT/out/vi-comparison/windows"
elif [[ "$WINDOWS_PUBLISH_ROOT" != /* ]]; then
  WINDOWS_PUBLISH_ROOT="$LOCALCI_REPO_ROOT/$WINDOWS_PUBLISH_ROOT"
fi

RUN_STAMP="$(basename "$LOCALCI_RUN_ROOT")"
STAGE_DIR="$LOCALCI_RUN_ROOT/vi-comparison"
REQUESTS_PATH="$STAGE_DIR/vi-diff-requests.json"
SUMMARY_PATH="$STAGE_DIR/vi-comparison-summary.json"
CAPTURES_ROOT="$STAGE_DIR/captures"
REPORT_MD="$STAGE_DIR/vi-comparison-report.md"
REPORT_HTML="$STAGE_DIR/vi-comparison-report.html"
FINAL_PUBLISH_BASE="$LOCALCI_REPO_ROOT/out/vi-comparison"
FINAL_PUBLISH_DIR="$FINAL_PUBLISH_BASE/$RUN_STAMP"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

find_windows_publish() {
  python3 - <<'PY' "$WINDOWS_PUBLISH_ROOT" "$RUN_STAMP"
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
target = sys.argv[2]
if not root.is_dir():
    print('')
    sys.exit(0)
candidates = []
for publish in root.glob('*/publish.json'):
    try:
        data = json.loads(publish.read_text(encoding='utf-8'))
    except Exception:
        continue
    if data.get('ubuntuPayload') == target:
        run = data.get('windowsRun') or ''
        candidates.append((run, str(publish)))
if not candidates:
    print('')
else:
    candidates.sort()
    print(candidates[-1][1])
PY
}

WINDOWS_PUBLISH_JSON_OVERRIDE="${LOCALCI_WINDOWS_PUBLISH_JSON:-}"
WINDOWS_PUBLISH_JSON="$(find_windows_publish)"
USING_WINDOWS=false

if [[ -n "$WINDOWS_PUBLISH_JSON_OVERRIDE" ]]; then
  if [[ -f "$WINDOWS_PUBLISH_JSON_OVERRIDE" ]]; then
    WINDOWS_PUBLISH_JSON="$WINDOWS_PUBLISH_JSON_OVERRIDE"
  else
    echo "[vi-compare] LOCALCI_WINDOWS_PUBLISH_JSON set but file not found: $WINDOWS_PUBLISH_JSON_OVERRIDE" >&2
  fi
fi

if [[ -n "$WINDOWS_PUBLISH_JSON" && -f "$WINDOWS_PUBLISH_JSON" ]]; then
  WINDOWS_MATCH_DIR="$(dirname "$WINDOWS_PUBLISH_JSON")"
  echo "[vi-compare] Found Windows publish summary at $WINDOWS_PUBLISH_JSON"
  cp -R "$WINDOWS_MATCH_DIR"/. "$STAGE_DIR"
  USING_WINDOWS=true
else
  echo "[vi-compare] No Windows publish found for run $RUN_STAMP; generating local stub."
fi

INVOKE_SCRIPT="$LOCALCI_REPO_ROOT/src/tools/icon-editor/Invoke-FixtureViDiffs.ps1"
RENDER_SCRIPT="$LOCALCI_REPO_ROOT/src/tools/icon-editor/Render-ViComparisonReport.ps1"

generate_stub_payload() {
  mkdir -p "$CAPTURES_ROOT"

  generate_default_requests() {
    cat > "$REQUESTS_PATH" <<'JSON'
{
  "schema": "icon-editor/vi-diff-requests@v1",
  "count": 3,
  "requests": [
    { "name": "module_1.vi", "relPath": "src/VIs/module_1.vi", "category": "sample" },
    { "name": "module_2.vi", "relPath": "src/VIs/module_2.vi", "category": "sample" },
    { "name": "module_3.vi", "relPath": "src/VIs/module_3.vi", "category": "sample" }
  ]
}
JSON
  }

  if [[ -n "$VI_REQUESTS_TEMPLATE" ]]; then
    TEMPLATE_PATH="$LOCALCI_REPO_ROOT/$VI_REQUESTS_TEMPLATE"
    if [[ ! -f "$TEMPLATE_PATH" ]]; then
      echo "[vi-compare] Requests template '$VI_REQUESTS_TEMPLATE' not found; aborting." >&2
      exit 1
    fi
    cp "$TEMPLATE_PATH" "$REQUESTS_PATH"
  else
    generate_default_requests
  fi

  if [[ ! -f "$INVOKE_SCRIPT" ]]; then
    echo "[vi-compare] Invoke-FixtureViDiffs.ps1 not found at $INVOKE_SCRIPT" >&2
    exit 1
  fi

  invoke_cmd="& '$INVOKE_SCRIPT' -RequestsPath '$REQUESTS_PATH' -CapturesRoot '$CAPTURES_ROOT' -SummaryPath '$SUMMARY_PATH'"
  if [[ "$VI_DRY_RUN" == "true" ]]; then
    invoke_cmd+=" -DryRun"
  fi

  pwsh -NoLogo -NoProfile -Command "$invoke_cmd" | tee "$STAGE_DIR/invoke-fixture-vi-diffs.log" >/dev/null
  echo "[vi-compare] Summary written to $SUMMARY_PATH"
}

if [[ "$USING_WINDOWS" == "true" ]]; then
  if [[ ! -f "$SUMMARY_PATH" ]]; then
    echo "[vi-compare] Windows publish missing summary at $SUMMARY_PATH; falling back to stub."
    USING_WINDOWS=false
  fi
fi

if [[ "$USING_WINDOWS" != "true" ]]; then
  generate_stub_payload
fi

if [[ ! -f "$RENDER_SCRIPT" ]]; then
  echo "[vi-compare] Render-ViComparisonReport.ps1 not found at $RENDER_SCRIPT" >&2
  exit 1
fi

python3 - <<'PY' "$SUMMARY_PATH"
import sys, json
path = sys.argv[1]
data = json.loads(open(path, encoding='utf-8').read())
changed = False
for req in data.get('requests', []):
    if 'message' not in req or req['message'] is None:
        req['message'] = ''
        changed = True
if changed:
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(data, handle, indent=2)
PY

pwsh -NoLogo -NoProfile -Command "& '$RENDER_SCRIPT' -SummaryPath '$SUMMARY_PATH' -OutputPath '$REPORT_MD'" >/dev/null
echo "[vi-compare] Markdown report written to $REPORT_MD"

python3 - <<'PY' "$SUMMARY_PATH" "$REPORT_HTML"
import sys, json, html
from pathlib import Path
summary_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
data = json.loads(summary_path.read_text(encoding='utf-8'))
counts = data.get('counts', {})
rows = ["<tr><th>VI</th><th>Status</th><th>Message</th><th>Artifacts</th></tr>"]
for req in data.get('requests', []):
    vi = html.escape(req.get('relPath') or req.get('name') or '(unknown)')
    status = html.escape(req.get('status') or 'unknown')
    message = html.escape(req.get('message') or '')
    artifacts = req.get('artifacts') or {}
    links = []
    if artifacts.get('captureJson'):
        links.append(f"<a href='{html.escape(artifacts['captureJson'])}'>capture</a>")
    if artifacts.get('sessionIndex'):
        links.append(f"<a href='{html.escape(artifacts['sessionIndex'])}'>session-index</a>")
    if not links:
        links.append('&mdash;')
    rows.append(f"<tr><td>{vi}</td><td>{status}</td><td>{message}</td><td>{'<br/>'.join(links)}</td></tr>")
html_doc = f"""<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='utf-8'/>
  <title>VI Comparison Report</title>
  <style>
    body{{font-family:Arial, sans-serif; margin:2rem}}
    table{{border-collapse:collapse; width:100%}}
    th,td{{border:1px solid #ccc; padding:0.4rem}}
    th{{background:#f4f4f4}}
  </style>
</head>
<body>
  <h1>VI Comparison Report</h1>
  <p>Compared: {counts.get('total',0)} total, {counts.get('same',0)} same, {counts.get('different',0)} different,
     {counts.get('skipped',0)} skipped, {counts.get('dryRun',0)} dry-run, {counts.get('errors',0)} errors.</p>
  <table>
    {''.join(rows)}
  </table>
</body>
</html>"""
output_path.write_text(html_doc, encoding='utf-8')
print(f"[vi-compare] HTML report written to {output_path}")
PY

mkdir -p "$FINAL_PUBLISH_BASE"
rm -rf "$FINAL_PUBLISH_DIR"
mkdir -p "$FINAL_PUBLISH_DIR"
cp -R "$STAGE_DIR"/. "$FINAL_PUBLISH_DIR"
echo "[vi-compare] Published rendered artifacts to $FINAL_PUBLISH_DIR"

if [[ "$USING_WINDOWS" == "true" ]]; then
  python3 - <<'PY' "$LOCALCI_RUN_ROOT" "$WINDOWS_PUBLISH_JSON"
import json, sys
from datetime import datetime, timezone
run_root = sys.argv[1]
publish_path = sys.argv[2]
payload = {
    "state": "done",
    "completed_at_utc": datetime.now(timezone.utc).isoformat(),
    "windows_publish": publish_path
}
done_path = f"{run_root}/_DONE"
with open(done_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
print(f"[vi-compare] Marked run complete via {done_path}")
PY
fi

echo "[vi-compare] Completed VI comparison stage."
