# open-new-ci.ps1
# Overwrites .github/workflows/ci.yml with a full matrix (validate, pester, jest)
# then opens it in Notepad.

$ymlPath = '.github/workflows/ci.yml'

$ci = @'
name: Insight CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Insight files
        shell: pwsh
        run: |
          $files = git ls-files '*.insight.json'
          if ($files) {
            ./scripts/validate-insight.ps1 -Path $files
          } else {
            Write-Host 'No Insight files to validate.'
          }

  pester:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Pester
        shell: pwsh
        run: Install-Module -Name Pester -Force
      - name: Run Pester tests
        shell: pwsh
        run: |
          Invoke-Pester -Path tests/pester -Output Detailed
      - name: Upload Pester results
        uses: actions/upload-artifact@v4
        with:
          name: pester-results
          path: TestResults.xml
          if-no-files-found: ignore

  jest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node 18
        uses: actions/setup-node@v4
        with:
          node-version: 18
      - name: Install deps and build
        run: |
          cd tooling/vscode-seed-insight
          npm ci
          npm run build
      - name: Run Jest
        run: |
          cd tooling/vscode-seed-insight
          npm test -- --coverage --runInBand
      - name: Upload Jest coverage
        uses: actions/upload-artifact@v4
        with:
          name: jest-coverage
          path: tooling/vscode-seed-insight/coverage
'@

# ensure folder exists
$dir = Split-Path $ymlPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

# overwrite workflow
$ci | Set-Content -Encoding utf8 -Path $ymlPath

Write-Host "`nOpening Notepad for $ymlPath ..."
Start-Process notepad $ymlPath -Wait

Write-Host "`nAll done.  Next:"
Write-Host "  git add $ymlPath"
Write-Host "  git commit -m 'CI: add Pester & Jest jobs'"
Write-Host "  git push origin main`n"
