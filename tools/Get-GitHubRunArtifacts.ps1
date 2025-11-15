#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RunIdOrUrl,

    # Optional override for owner/repo (e.g. LabVIEW-Community-CI-CD/icon-editor-lab).
    [string]$Repository,

    [string]$DestinationRoot,

    [string[]]$ArtifactNames,

    # Optional token for REST fallback when gh is not authenticated.
    [string]$GitHubToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoSlug {
    param(
        [string]$RepoRoot,
        [string]$ExplicitRepository
    )

    if ($ExplicitRepository) {
        # Accept "owner/name" directly.
        if ($ExplicitRepository -match '^[^/]+/[^/]+$') {
            return $ExplicitRepository
        }
        # Accept full HTTPS or SSH remote URLs.
        if ($ExplicitRepository -match 'github\.com[:/](?<owner>[^/]+)/(?<name>[^/.]+)') {
            return "$($Matches.owner)/$($Matches.name)"
        }
    }

    $slug = $null
    try {
        $remote = git -C $RepoRoot remote get-url origin 2>$null
        if ($remote) {
            if ($remote -match 'github\.com[:/](?<owner>[^/]+)/(?<name>[^/.]+)') {
                $slug = "$($Matches.owner)/$($Matches.name)"
            }
        }
    } catch {
    }
    if (-not $slug -and $env:GITHUB_REPOSITORY) {
        $slug = $env:GITHUB_REPOSITORY
    }
    return $slug
}

function Parse-RunId {
    param([string]$Value)

    if (-not $Value) {
        throw "RunIdOrUrl is required and cannot be empty."
    }

    # Full run URL (…/actions/runs/<id> or …/runs/<id>)
    if ($Value -match '/actions/runs/(?<id>\d+)') {
        return $Matches['id']
    }
    if ($Value -match '/runs/(?<id>\d+)') {
        return $Matches['id']
    }

    # Plain numeric id
    if ($Value -match '^\d+$') {
        return $Value
    }

    # Heuristic: last numeric segment (covers copy/pasted console hints)
    if ($Value -match '(\d+)$') {
        Write-Warning ("[gha-artifacts] Heuristically using '{0}' as run id from input '{1}'." -f $Matches[1], $Value)
        return $Matches[1]
    }

    throw "Could not extract a numeric run id from '$Value'."
}

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') -ErrorAction Stop).ProviderPath
$repoRoot = $root

if (-not $DestinationRoot) {
    $DestinationRoot = Join-Path $repoRoot 'logs-artifacts'
}

if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

$runId = Parse-RunId -Value $RunIdOrUrl
$repoSlug = Get-RepoSlug -RepoRoot $repoRoot -ExplicitRepository $Repository
if (-not $repoSlug) {
    throw "Unable to determine GitHub repo slug from git remote or GITHUB_REPOSITORY."
}

Write-Host "[gha-artifacts] Repo     : $repoSlug" -ForegroundColor DarkGray
Write-Host "[gha-artifacts] Run id   : $runId" -ForegroundColor DarkGray
Write-Host "[gha-artifacts] Dest root: $DestinationRoot" -ForegroundColor DarkGray

$gh = Get-Command gh -ErrorAction SilentlyContinue
$ghAuthOk = $false
if ($gh) {
    try {
        & $gh.Path auth status 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $ghAuthOk = $true
        }
    } catch {
        $ghAuthOk = $false
    }
}

if ($gh -and $ghAuthOk) {
    Write-Host "[gha-artifacts] Using gh CLI for download." -ForegroundColor Cyan

    $names = if ($ArtifactNames -and $ArtifactNames.Count -gt 0) { $ArtifactNames } else { @() }
    if (-not $names -or $names.Count -eq 0) {
        # Discover artifact names when not specified
        try {
            $json = & $gh.Path run view $runId --repo $repoSlug --json artifacts --jq '.artifacts[].name' 2>$null
            if ($LASTEXITCODE -eq 0 -and $json) {
                $names = $json -split '\r?\n' | Where-Object { $_ }
            }
        } catch {
        }
    }

    if (-not $names -or $names.Count -eq 0) {
        Write-Warning "[gha-artifacts] No artifact names provided and none discovered via gh; downloading all artifacts."
        $names = @()
    }

    if ($names -and $names.Count -gt 0) {
        foreach ($name in $names) {
            $safeName = $name.Trim()
            if (-not $safeName) { continue }
            $dest = Join-Path $DestinationRoot $safeName
            if (-not (Test-Path -LiteralPath $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
            Write-Host "[gha-artifacts] Downloading '$safeName' -> $dest" -ForegroundColor DarkGray
            & $gh.Path run download $runId --repo $repoSlug --name $safeName --dir $dest
            if ($LASTEXITCODE -ne 0) {
                Write-Error "[gha-artifacts] gh run download failed for '$safeName' (exit $LASTEXITCODE)."
                return
            }
        }
    } else {
        # Download all artifacts into the destination root
        Write-Host "[gha-artifacts] Downloading all artifacts into $DestinationRoot" -ForegroundColor DarkGray
        & $gh.Path run download $runId --repo $repoSlug --dir $DestinationRoot
        if ($LASTEXITCODE -ne 0) {
            # If artifact directories already exist, treat this as a non-fatal re-run.
            $existing = Get-ChildItem -LiteralPath $DestinationRoot -Directory -ErrorAction SilentlyContinue
            if ($existing -and $existing.Count -gt 0) {
                Write-Warning "[gha-artifacts] gh run download reported a failure, but artifact directories already exist; assuming this is a re-run and leaving existing content in place."
            } else {
                Write-Error "[gha-artifacts] gh run download failed (exit $LASTEXITCODE)."
                return
            }
        }
    }
} else {
    Write-Warning "[gha-artifacts] gh CLI not available or not authenticated; attempting REST API fallback."

    $token = $GitHubToken
    if (-not $token -and $env:GITHUB_TOKEN) {
        $token = $env:GITHUB_TOKEN
    }

    if (-not $token) {
        Write-Warning "[gha-artifacts] No GitHub token available; download artifacts manually from the Actions UI or run this script where gh is authenticated."
        return
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept        = 'application/vnd.github+json'
        'User-Agent'  = 'icon-editor-lab/Get-GitHubRunArtifacts'
    }

    $baseApi = "https://api.github.com/repos/$repoSlug"
    $artifactsUri = "$baseApi/actions/runs/$runId/artifacts?per_page=100"

    Write-Host "[gha-artifacts] Listing artifacts via REST API..." -ForegroundColor DarkGray
    try {
        $response = Invoke-RestMethod -Method Get -Uri $artifactsUri -Headers $headers -ErrorAction Stop
    } catch {
        Write-Error "[gha-artifacts] Failed to list artifacts via REST API: $($_.Exception.Message)"
        return
    }

    if (-not $response -or -not $response.artifacts) {
        Write-Warning "[gha-artifacts] No artifacts returned by REST API for run $runId."
        return
    }

    $allArtifacts = @($response.artifacts)

    $targetNames = if ($ArtifactNames -and $ArtifactNames.Count -gt 0) {
        $ArtifactNames
    } else {
        $allArtifacts | ForEach-Object { $_.name } | Sort-Object -Unique
    }

    if (-not $targetNames -or $targetNames.Count -eq 0) {
        Write-Warning "[gha-artifacts] No artifact names resolved for REST download."
        return
    }

    foreach ($name in $targetNames) {
        $safeName = $name.Trim()
        if (-not $safeName) { continue }

        $artifact = $allArtifacts | Where-Object { $_.name -eq $safeName } | Select-Object -First 1
        if (-not $artifact) {
            Write-Warning ("[gha-artifacts] Artifact '{0}' not found in run {1}; skipping." -f $safeName, $runId)
            continue
        }

        $downloadUri = "$baseApi/actions/artifacts/$($artifact.id)/zip"
        $destDir = Join-Path $DestinationRoot $safeName
        if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $zipPath = Join-Path $DestinationRoot ("{0}.zip" -f $safeName.Replace(' ', '_'))

        Write-Host ("[gha-artifacts] Downloading '{0}' via REST -> {1}" -f $safeName, $destDir) -ForegroundColor DarkGray
        try {
            Invoke-WebRequest -Method Get -Uri $downloadUri -Headers $headers -OutFile $zipPath -ErrorAction Stop
        } catch {
            Write-Error ("[gha-artifacts] Failed to download artifact '{0}' via REST: {1}" -f $safeName, $_.Exception.Message)
            if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            }
            continue
        }

        try {
            Expand-Archive -LiteralPath $zipPath -DestinationPath $destDir -Force -ErrorAction Stop
        } catch {
            Write-Error ("[gha-artifacts] Failed to extract artifact '{0}' from '{1}': {2}" -f $safeName, $zipPath, $_.Exception.Message)
        } finally {
            if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host "[gha-artifacts] Artifact download completed." -ForegroundColor Green
