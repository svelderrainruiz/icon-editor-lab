#Requires -Version 7.0
param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot  = $Context.RepoRoot
$signRoot  = $Context.SignRoot
$runRoot   = $Context.RunRoot
$hashScript = Join-Path $repoRoot 'tools' 'Hash-Artifacts.ps1'
$exclusions = @('local-signing-logs','local-ci')

if (-not (Get-ChildItem -LiteralPath $signRoot -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $exclusions -notcontains $_.Directory.Name })) {
    Write-Warning "No candidate files under $signRoot to package."
    return
}

if (-not (Test-Path -LiteralPath $hashScript)) {
    throw "Hash-Artifacts.ps1 not found at $hashScript"
}

$packRoot = Join-Path $runRoot 'pack-root'
if (Test-Path -LiteralPath $packRoot) { Remove-Item -LiteralPath $packRoot -Recurse -Force }
New-Item -ItemType Directory -Path $packRoot -Force | Out-Null

Get-ChildItem -LiteralPath $signRoot -Force |
    Where-Object { $exclusions -notcontains $_.Name } |
    ForEach-Object {
        $destination = Join-Path $packRoot $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        } else {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
    }

Write-Host "Hashing artifacts under $packRoot"
$cmdInfo = Get-Command pwsh -ErrorAction SilentlyContinue
$pwshCmd = $null
if ($cmdInfo) {
    if ($cmdInfo.PSObject.Properties['Path']) { $pwshCmd = $cmdInfo.Path }
    elseif ($cmdInfo.PSObject.Properties['Source']) { $pwshCmd = $cmdInfo.Source }
}
if (-not $pwshCmd -and $IsWindows) {
    $candidate = Join-Path $PSHOME 'pwsh.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $pwshCmd = $candidate }
}
if (-not $pwshCmd) { $pwshCmd = 'pwsh' }
& $pwshCmd -NoLogo -NoProfile -File $hashScript -Root $packRoot -Output 'checksums.sha256'

$zipPath = Join-Path $runRoot 'signed-artifacts.zip'
Write-Host "Creating archive $zipPath"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $packRoot '*') -DestinationPath $zipPath -Force
Write-Host "Packaged artifacts to $zipPath"
Remove-Item -LiteralPath $packRoot -Recurse -Force -ErrorAction SilentlyContinue
