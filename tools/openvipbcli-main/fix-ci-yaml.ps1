# fix-ci-yaml.ps1
$path = '.github/workflows/ci.yml'

if (-not (Test-Path $path)) {
  Write-Error "$path not found — did the workflow get committed?"
  exit 1
}

Write-Host "Opening $path in Notepad...`nReplace all `\$files` with `$files`, remove leading back-slashes, save & close."
Start-Process notepad $path -Wait

git add $path
git commit -m "Fix CI script variable syntax"
git push origin main
Write-Host "`n✅ Push complete — watch the Actions tab for a green run."
