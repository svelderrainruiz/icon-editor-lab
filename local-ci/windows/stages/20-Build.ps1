#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $Context.RepoRoot
$signRoot = $Context.SignRoot

Write-Host "Preparing build artifacts under $signRoot"

$preserve = @('local-signing-logs','local-ci')
Get-ChildItem -LiteralPath $signRoot -Force -ErrorAction SilentlyContinue |
    Where-Object { $preserve -notcontains $_.Name } |
    Remove-Item -Recurse -Force

function Copy-Payload {
    param([string]$SourceFolder)
    $source = Join-Path $repoRoot $SourceFolder
    if (-not (Test-Path -LiteralPath $source)) { return }

    Get-ChildItem -LiteralPath $source -Include *.ps1,*.psm1 -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $relative = $_.FullName.Substring($repoRoot.Length + 1)
            $destination = Join-Path $signRoot $relative
            $destDir = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
}

Copy-Payload -SourceFolder 'tools'
Copy-Payload -SourceFolder 'scripts'

# Sample payloads for integration tests
"Write-Output 'Sample payload for local CI build.'" |
    Set-Content -LiteralPath (Join-Path $signRoot 'Sample-Signed.ps1') -Encoding UTF8
[IO.File]::WriteAllBytes((Join-Path $signRoot 'sample.exe'), [byte[]](1..32))

Write-Host "Build stage complete. $(Get-ChildItem -LiteralPath $signRoot -Recurse -File | Measure-Object).Count files staged."
