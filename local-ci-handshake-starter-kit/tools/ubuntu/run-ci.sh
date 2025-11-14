#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
UBUNTU_OUT="$REPO_ROOT/out/local-ci-ubuntu"
mkdir -p "$UBUNTU_OUT"

ts="$(date -u +"%Y%m%d-%H%M%SZ")"
short="$(git rev-parse --short HEAD 2>/dev/null || echo 'nogit')"
run_id="${ts}-${short}-01"
run_dir="$UBUNTU_OUT/$run_id"
mkdir -p "$run_dir"

# Example diff requests (replace with your generator)
cat > "$run_dir/vi-diff-requests.json" <<'JSON'
{
  "schema_version":"v1",
  "run_id":"__RUN_ID__",
  "labview":{"target_version":"2023 SP1 64-bit","compare_options":{"ignoreCosmetic":true}},
  "pairs":[
    {"pair_id":"0001","baseline":{"path":"source/Baseline/Controller.vi"},"candidate":{"path":"source/FeatureX/Controller.vi"}},
    {"pair_id":"0002","baseline":{"path":"source/Baseline/Utils/ErrorHandler.vi"},"candidate":{"path":"source/FeatureX/Utils/ErrorHandler.vi"}}
  ],
  "render_hints":{"captureFrontPanelPng":true,"captureBlockDiagramPng":true}
}
JSON
sed -i.bak "s/__RUN_ID__/$run_id/g" "$run_dir/vi-diff-requests.json"

# Optional build/test artifacts
( cd "$REPO_ROOT" && mkdir -p tmp/ci && echo "example build artifact" > tmp/ci/build.txt )
( cd "$REPO_ROOT/tmp/ci" && zip -qr "$run_dir/artifacts-ubuntu.zip" . )

cat > "$run_dir/ubuntu-run.json" <<JSON
{
  "schema_version":"v1",
  "run_id":"__RUN_ID__",
  "created_utc":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project":{"name":"AcmeLabVIEWProject","repo":"git","branch":"$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)","commit":"$(git rev-parse HEAD 2>/dev/null || echo none)","dirty":false},
  "tooling":{"ubuntu_ci_tool_version":"1.3.0","renderer_version":"2.5.1"},
  "path_map":[{"purpose":"interop_root","windows":"C:\\\\repo\\\\acme\\\\out","wsl":"/mnt/c/repo/acme/out"}],
  "artifacts":{"zip":"out/local-ci-ubuntu/__RUN_ID__/artifacts-ubuntu.zip"},
  "vi_diff_requests_file":"out/local-ci-ubuntu/__RUN_ID__/vi-diff-requests.json",
  "determinism":{"sort":"lexicographic","locale":"C","case_sensitive":true}
}
JSON
sed -i.bak "s/__RUN_ID__/$run_id/g" "$run_dir/ubuntu-run.json"

# Signal READY last
touch "$run_dir/_READY"
echo "Prepared run: $run_id at $run_dir"
