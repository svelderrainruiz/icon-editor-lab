#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-UbuntuRunImport {
    [CmdletBinding()]
    param(
        [string]$ManifestPath,
        [string]$RepoRoot,
        [string]$RunRoot,
        [string]$SignRoot,
        [switch]$SkipGitCheck,
        [switch]$NoExtract
    )

    function Resolve-UbuntuManifestPath {
        param([string]$InputPath)
        if (-not $InputPath) {
            $InputPath = $env:LOCALCI_IMPORT_UBUNTU_RUN
        }
        if (-not $InputPath) {
            return $null
        }
        $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction SilentlyContinue
        if (-not $resolved) {
            throw "Specified Ubuntu manifest path '$InputPath' does not exist."
        }
        $candidate = $resolved.ProviderPath
        if ((Test-Path -LiteralPath $candidate -PathType Container)) {
            $jsonPath = Join-Path $candidate 'ubuntu-run.json'
            if (-not (Test-Path -LiteralPath $jsonPath)) {
                throw "Directory '$candidate' does not contain ubuntu-run.json"
            }
            return $jsonPath
        }
        return $candidate
    }

    $manifestPath = Resolve-UbuntuManifestPath -InputPath $ManifestPath
    if (-not $manifestPath) {
        Write-Verbose 'No Ubuntu manifest provided; skipping import.'
        return $null
    }

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Ubuntu manifest '$manifestPath' not found."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 8
    if (-not $manifest.runner -or $manifest.runner -ne 'ubuntu') {
        throw "Manifest '$manifestPath' does not represent an Ubuntu local CI run."
    }

    $paths = $manifest.paths
    if (-not $RepoRoot -and $paths -and $paths.PSObject.Properties.Match('repo_root').Count -gt 0) {
        $RepoRoot = $paths.repo_root
    }
    if (-not $RepoRoot) {
        throw 'RepoRoot not provided and manifest is missing paths.repo_root.'
    }
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath

    if (-not $RunRoot) {
        throw 'RunRoot is required.'
    }
    if (-not (Test-Path -LiteralPath $RunRoot)) {
        New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
    }

    if (-not $SignRoot -and $paths -and $paths.PSObject.Properties.Match('sign_root').Count -gt 0) {
        $SignRoot = $paths.sign_root
    }

    if (-not $SkipGitCheck) {
        try {
            $repoCommit = git -C $RepoRoot rev-parse HEAD
        } catch {
            throw "git command failed while validating repo: $($_.Exception.Message)"
        }
        $repoCommit = $repoCommit.Trim()
        $manifestCommit = ($manifest.git.commit ?? '').Trim()
        if (-not $manifestCommit) {
            throw 'Manifest missing git.commit; cannot validate.'
        }
        if ($repoCommit.ToLowerInvariant() -ne $manifestCommit.ToLowerInvariant()) {
            throw "Repo commit '$repoCommit' does not match Ubuntu manifest commit '$manifestCommit'. Rerun Ubuntu local CI."
        }
    }

    $zipRel = $null
    $zipAbs = $null
    if ($paths) {
        if ($paths.PSObject.Properties.Match('artifact_zip_rel').Count -gt 0) {
            $zipRel = $paths.artifact_zip_rel
        }
        if ($paths.PSObject.Properties.Match('artifact_zip_abs').Count -gt 0) {
            $zipAbs = $paths.artifact_zip_abs
        }
    }
    $zipPath = $null
    if ($zipRel) {
        $zipPath = Join-Path $RepoRoot $zipRel
    }
    if (-not $zipPath -and $zipAbs) {
        $zipPath = $zipAbs
    }
    if (-not $zipPath -or -not (Test-Path -LiteralPath $zipPath)) {
        throw "Artifact zip from manifest not found. Expected repo-relative '$zipRel'."
    }

    $extractPath = Join-Path $RunRoot 'ubuntu-artifacts'
    if (-not $NoExtract) {
        if (Test-Path -LiteralPath $extractPath) {
            Remove-Item -LiteralPath $extractPath -Recurse -Force
        }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    }

    $expectedHash = $null
    if ($paths -and $paths.PSObject.Properties.Match('artifact_hash').Count -gt 0) {
        $expectedHash = $paths.artifact_hash
    }
    if (-not $expectedHash -and $manifest.coverage -and $manifest.coverage.PSObject.Properties.Match('hash').Count -gt 0) {
        $expectedHash = $manifest.coverage.hash
    }
    if (-not $expectedHash) {
        $hashFile = Join-Path (Split-Path -Parent $zipPath) 'checksums.sha256'
        if (Test-Path -LiteralPath $hashFile) {
            $line = Get-Content -LiteralPath $hashFile -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($line -match '^[0-9a-fA-F]{64}') { $expectedHash = $line.Substring(0,64) }
        }
    }
    $hashStatus = $null
    if ($expectedHash) {
        $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
        if ($zipHash.ToLowerInvariant() -ne $expectedHash.ToLowerInvariant()) {
            throw "Artifact hash mismatch for '$zipPath'"
        }
        $hashStatus = [ordered]@{
            expected = $expectedHash
            actual   = $zipHash
            verified = $true
        }
    }

    $coveragePayload = $manifest.coverage
    $coveragePercent = if ($coveragePayload) { $coveragePayload.percent } else { $null }

    $summary = [ordered]@{
        ManifestPath  = $manifestPath
        ImportedZip   = $zipPath
        ExtractedPath = if ($NoExtract) { $null } else { $extractPath }
        GitCommit     = $manifest.git.commit
        GitBranch     = $manifest.git.branch
        Coverage      = $coveragePayload
        HashStatus    = $hashStatus
        Timestamp     = $manifest.timestamp
    }
    $summaryPath = Join-Path $RunRoot 'ubuntu-import.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    Write-Host ("Imported Ubuntu run manifest at {0} (coverage: {1})" -f $manifestPath, ($coveragePercent ?? 'n/a'))

    return [pscustomobject]@{
        Manifest     = $manifest
        SummaryPath  = $summaryPath
        ExtractedDir = if ($NoExtract) { $null } else { $extractPath }
        ZipPath      = $zipPath
    }
}

Export-ModuleMember -Function Invoke-UbuntuRunImport
