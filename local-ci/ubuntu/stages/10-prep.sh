#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_SIGN_ROOT:?LOCALCI_SIGN_ROOT not set}"
: "${LOCALCI_RUN_ROOT:?LOCALCI_RUN_ROOT not set}"
: "${LOCALCI_REPO_ROOT:?LOCALCI_REPO_ROOT not set}"

echo "Sign root : $LOCALCI_SIGN_ROOT"
echo "Run root  : $LOCALCI_RUN_ROOT"

mkdir -p "$LOCALCI_SIGN_ROOT" "$LOCALCI_RUN_ROOT"

missing=()
if ! command -v pwsh >/dev/null 2>&1; then
  missing+=("pwsh")
fi
if ! command -v python3 >/dev/null 2>&1; then
  missing+=("python3")
fi
if ! command -v zip >/dev/null 2>&1; then
  echo "[10-prep] zip CLI not found; packaging stage will use Python fallback." >&2
fi
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "[10-prep] Missing required commands: ${missing[*]}" >&2
  exit 1
fi

pwsh -NoLogo -NoProfile -Command - <<'PWSH'
$ErrorActionPreference = 'Stop'
function Ensure-Module {
    param([string]$Name,[version]$Minimum)
    $have = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -ge $Minimum }
    if (-not $have) {
        Write-Host "[10-prep] Installing module $Name (>= $Minimum)" -ForegroundColor Yellow
        Install-Module -Name $Name -MinimumVersion $Minimum -Scope CurrentUser -Force -ErrorAction Stop
    }
}
Ensure-Module -Name Pester -Minimum ([version]'5.4.0')
Ensure-Module -Name ThreadJob -Minimum ([version]'2.0.0')
PWSH

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
