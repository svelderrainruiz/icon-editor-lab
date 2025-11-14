#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [string]$TargetPath,
    [string]$RemoteUrl = 'https://github.com/LabVIEW-Community-CI-CD/labview-icon-editor.git',
    [string]$Ref = 'main',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param([string]$Path, [string]$BasePath)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    $combined = [System.IO.Path]::Combine($BasePath, $Path)
    return (Resolve-Path -LiteralPath $combined -ErrorAction Stop).Path
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "[Sync-IconEditorVendor] git.exe not found on PATH."
}

$repoResolved = (Resolve-Path -LiteralPath $RepoRoot).Path
$targetPath = if ($TargetPath) {
    Resolve-AbsolutePath -Path $TargetPath -BasePath $repoResolved
} else {
    [System.IO.Path]::Combine($repoResolved, 'vendor', 'labview-icon-editor')
}

$targetDir = [System.IO.Path]::GetDirectoryName($targetPath)
if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    [void][System.IO.Directory]::CreateDirectory($targetDir)
}

$gitDir = Join-Path $targetPath '.git'
$hasRepo = Test-Path -LiteralPath $gitDir -PathType Container

function Invoke-Git {
    param([string[]]$Arguments, [string]$WorkingDirectory = $targetPath)
    $result = git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "[Sync-IconEditorVendor] git $($Arguments -join ' ') failed: $result"
    }
    return $result
}

function Update-WorkingTree {
    Write-Host ("[Sync-IconEditorVendor] Fetching {0} ({1})" -f $RemoteUrl, $Ref)
    Invoke-Git -Arguments @('fetch', 'origin', $Ref, '--depth', '1')
    Invoke-Git -Arguments @('checkout', '--force', 'FETCH_HEAD')
    Invoke-Git -Arguments @('reset', '--hard', 'FETCH_HEAD')
    Invoke-Git -Arguments @('clean', '-fdx')
}

if ($hasRepo -and -not $Force.IsPresent) {
    Update-WorkingTree
} else {
    if ($hasRepo) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }
    Write-Host ("[Sync-IconEditorVendor] Cloning {0} -> {1}" -f $RemoteUrl, $targetPath)
    $cloneArgs = @('clone', '--depth', '1', $RemoteUrl, $targetPath)
    $clone = git @cloneArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "[Sync-IconEditorVendor] git clone failed: $clone"
    }
    Push-Location -LiteralPath $targetPath
    try {
        Update-WorkingTree
    } finally {
        Pop-Location
    }
}

[pscustomobject]@{
    Path   = (Resolve-Path -LiteralPath $targetPath).Path
    Remote = $RemoteUrl
    Ref    = $Ref
}
