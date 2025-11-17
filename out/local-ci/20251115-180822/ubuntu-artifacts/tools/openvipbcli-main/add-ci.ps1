# add-ci.ps1  – create .github/workflows/ci.yml and push
$ymlPath = '.github/workflows/ci.yml'
if (-not (Test-Path '.github/workflows')) {
    New-Item -ItemType Directory -Path '.github/workflows' -Force | Out-Null
}
if (-not (Test-Path $ymlPath)) {
    @"
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
          \$files = git ls-files '*.insight.json'
          if (\$files) {
            ./scripts/validate-insight.ps1 -Path \$files
          } else {
            Write-Host 'No Insight files to validate.'
          }
"@ | Set-Content -Encoding utf8 -Path $ymlPath
    Start-Process notepad $ymlPath -Wait   # let you tweak, save, close
}

git add $ymlPath
git commit -m "Add Insight CI workflow"
git push origin main
Write-Host "`n✅ Workflow pushed. Check the Actions tab for a new run."
