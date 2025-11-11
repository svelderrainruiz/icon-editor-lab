#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$PWD}"
mkdir -p \
  "$ROOT"/{src,tools,tests,docs,adr,architecture/adr,.github/workflows,scripts,_merged/rc0.1.0}

if [ ! -f "$ROOT/docs/RTM.md" ]; then
  cat <<'EOF' > "$ROOT/docs/RTM.md"
# RTM (seed)

|Req|Test|Code|Evidence|
|---|---|---|---|
EOF
fi

if [ ! -f "$ROOT/adr/ADR-0001.md" ]; then
  cat <<'EOF' > "$ROOT/adr/ADR-0001.md"
# ADR-0001: Adopt Multi-Agent Orchestration

Status: Proposed

## Context

## Decision

## Consequences
EOF
fi

mkdir -p "$ROOT/tests"
if [ ! -f "$ROOT/tests/sample.tests.ps1" ]; then
  cat <<'EOF' > "$ROOT/tests/sample.tests.ps1"
Describe 'sample' {
  It 'passes' {
    1 | Should -Be 1
  }
}
EOF
fi

echo "Curate OK"
