#!/usr/bin/env bash
set -euo pipefail

: "${LOCALCI_PESTER_TAGS:=smoke}"
: "${LOCALCI_REPO_ROOT:?}"

RUNNER="$LOCALCI_REPO_ROOT/scripts/Invoke-RepoPester.ps1"
if [[ ! -f "$RUNNER" ]]; then
  echo "Runner $RUNNER not found" >&2
  exit 1
fi

pwsh -NoLogo -NoProfile -Command "
  \$ErrorActionPreference = 'Stop'
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
  \$hasPester = Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue |
    Where-Object { \$_.Version -ge [version]'5.0.0' } |
    Select-Object -First 1
  if (-not \$hasPester) {
    Install-Module -Name Pester -Scope CurrentUser -Force -MinimumVersion 5.0.0
  }
" >/dev/null

IFS=' ' read -r -a TAG_ARRAY <<< "$LOCALCI_PESTER_TAGS"
cmd="& '$RUNNER'"
if [[ ${#TAG_ARRAY[@]} -gt 0 ]]; then
  CLEAN_TAGS=()
  for tag in "${TAG_ARRAY[@]}"; do
    [[ -n "$tag" ]] || continue
    CLEAN_TAGS+=("$tag")
  done
  if [[ ${#CLEAN_TAGS[@]} -gt 0 ]]; then
    tag_expr="@("
    first=1
    for tag in "${CLEAN_TAGS[@]}"; do
      escaped="${tag//\'/\'\'}"
      if [[ $first -eq 0 ]]; then
        tag_expr+=", "
      fi
      tag_expr+="'$escaped'"
      first=0
    done
    tag_expr+=")"
    cmd+=" -Tag $tag_expr"
  fi
fi

cmd+=" -CI"
pwsh -NoLogo -NoProfile -Command "$cmd"
