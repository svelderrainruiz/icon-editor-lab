#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$DevModeDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $env:WORKSPACE_ROOT
if (-not $root) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

if ($DevModeDir) {
    $devmodeDir = (Resolve-Path -LiteralPath $DevModeDir -ErrorAction Stop).ProviderPath
    $xCliRoot = Split-Path -Parent (Split-Path -Parent $devmodeDir)
} else {
    $xCliRoot = Join-Path $root 'tools/x-cli-develop'
    $devmodeDir = Join-Path $xCliRoot 'temp_telemetry' 'labview-devmode'
}

if (-not (Test-Path -LiteralPath $devmodeDir -PathType Container)) {
    Write-Warning ("No labview-devmode telemetry directory found at '{0}'." -f $devmodeDir)
    return
}

$invocationFiles = Get-ChildItem -Path $devmodeDir -Filter 'invocations.jsonl' -File -Recurse -ErrorAction SilentlyContinue
if (-not $invocationFiles) {
    Write-Warning ("No labview-devmode invocation logs found under '{0}'." -f $devmodeDir)
    return
}

$records = @()
foreach ($file in $invocationFiles) {
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if (-not $line) { continue }
        try {
            $records += (ConvertFrom-Json -InputObject $line -ErrorAction Stop)
        } catch {
            Write-Warning ("Failed to parse labview-devmode record in '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        }
    }
}

if (-not $records) {
    Write-Warning ("No labview-devmode records parsed from '{0}'." -f $devmodeDir)
    return
}

$byOperation = @()
foreach ($group in $records | Group-Object -Property Operation) {
    $byMode = @()
    foreach ($modeGroup in $group.Group | Group-Object -Property Mode) {
        $byMode += [pscustomobject]@{
            Mode       = $modeGroup.Name
            Count      = $modeGroup.Count
            LvVersions = ($modeGroup.Group | ForEach-Object {
                if ($_ -is [psobject] -and $_.PSObject.Properties.Match('LvVersion').Count -gt 0) { $_.LvVersion } else { $null }
            } | Where-Object { $_ } | Sort-Object -Unique)
            Bitness    = ($modeGroup.Group | ForEach-Object {
                if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Bitness').Count -gt 0) { $_.Bitness } else { $null }
            } | Where-Object { $_ } | Sort-Object -Unique)
            Scripts    = ($modeGroup.Group | ForEach-Object {
                if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Script').Count -gt 0) { $_.Script } else { $null }
            } | Where-Object { $_ } | Sort-Object -Unique)
        }
    }

    $byOperation += [pscustomobject]@{
        Operation    = if ($group.Name) { $group.Name } else { '<none>' }
        Total        = $group.Count
        Modes        = $byMode
    }
}

$byRunId = @()
$hasRunId = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties.Match('RunId').Count -gt 0
} | Select-Object -First 1

if ($hasRunId) {
    foreach ($group in $records | Group-Object -Property RunId) {
        $exitCodes = @()
        foreach ($rec in $group.Group) {
            if ($rec -is [psobject] -and $rec.PSObject.Properties.Match('ExitCode').Count -gt 0) {
                $exitCodes += [int]$rec.ExitCode
            }
        }
        $exitCodes = $exitCodes | Sort-Object -Unique

        $outcome = '<none>'
        if (@($exitCodes).Count -gt 0) {
            if ($exitCodes | Where-Object { $_ -ne 0 -and $_ -ne 2 -and $_ -ne 130 }) {
                $outcome = 'failed'
            } elseif ($exitCodes -contains 130) {
                $outcome = 'aborted'
            } elseif ($exitCodes -contains 2) {
                $outcome = 'degraded'
            } else {
                $outcome = 'succeeded'
            }
        }

        $runRoots = ($group.Group | ForEach-Object {
            if ($_ -is [psobject] -and $_.PSObject.Properties.Match('LvaddonRoot').Count -gt 0) { $_.LvaddonRoot } else { $null }
        } | Where-Object { $_ } | Sort-Object -Unique)

        $byRunId += [pscustomobject]@{
            RunId      = if ($group.Name) { $group.Name } else { '<none>' }
            Total      = $group.Count
            Operations = ($group.Group | ForEach-Object { $_.Operation } | Where-Object { $_ } | Sort-Object -Unique)
            Modes      = ($group.Group | ForEach-Object { $_.Mode }      | Where-Object { $_ } | Sort-Object -Unique)
            ExitCodes  = $exitCodes
            Outcome    = $outcome
            LvaddonRoots = $runRoots
        }
    }
}

$configErrors = $null
$configErrorRecords = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties.Match('ConfigError').Count -gt 0 -and $_.ConfigError
}
if ($configErrorRecords) {
    $configErrors = [pscustomobject]@{
        Total   = $configErrorRecords.Count
        Reasons = ($configErrorRecords | ForEach-Object {
            if ($_ -is [psobject] -and $_.PSObject.Properties.Match('ConfigErrorDetail').Count -gt 0 -and $_.ConfigErrorDetail) {
                $_.ConfigErrorDetail
            } else {
                '<unknown>'
            }
        } | Group-Object | ForEach-Object {
            [pscustomobject]@{
                Reason = $_.Name
                Count  = $_.Count
            }
        })
    }
}

$resourceFailures = $null
$resourceErrorRecords = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties.Match('ResourceError').Count -gt 0 -and $_.ResourceError
}
if ($resourceErrorRecords) {
    $resourceFailures = [pscustomobject]@{
        Total   = $resourceErrorRecords.Count
        Reasons = ($resourceErrorRecords | ForEach-Object {
            if ($_ -is [psobject] -and $_.PSObject.Properties.Match('ResourceErrorDetail').Count -gt 0 -and $_.ResourceErrorDetail) {
                $_.ResourceErrorDetail
            } else {
                '<unknown>'
            }
        } | Group-Object | ForEach-Object {
            [pscustomobject]@{
                Reason = $_.Name
                Count  = $_.Count
            }
        })
    }
}

$toolchainFailures = $null
$toolchainErrorRecords = $records | Where-Object {
    $_ -is [psobject] -and $_.PSObject.Properties.Match('ToolchainError').Count -gt 0 -and $_.ToolchainError
}
if ($toolchainErrorRecords) {
    $toolchainFailures = [pscustomobject]@{
        Total   = $toolchainErrorRecords.Count
        Reasons = ($toolchainErrorRecords | ForEach-Object {
            if ($_ -is [psobject] -and $_.PSObject.Properties.Match('ToolchainErrorDetail').Count -gt 0 -and $_.ToolchainErrorDetail) {
                $_.ToolchainErrorDetail
            } else {
                '<unknown>'
            }
        } | Group-Object | ForEach-Object {
            [pscustomobject]@{
                Reason = $_.Name
                Count  = $_.Count
            }
        })
    }
}

$lvaddonRoots = $null
$lvaddonRootValues = $records | ForEach-Object {
    if ($_ -is [psobject] -and $_.PSObject.Properties.Match('LvaddonRoot').Count -gt 0) { $_.LvaddonRoot } else { $null }
} | Where-Object { $_ } | Sort-Object -Unique
if ($lvaddonRootValues) {
    $lvaddonRoots = @()
    foreach ($lvRoot in $lvaddonRootValues) {
        $inWorkspace = $false
        if ($root -and ($lvRoot -is [string])) {
            try {
                if ($lvRoot.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $inWorkspace = $true
                }
            } catch {
                $inWorkspace = $false
            }
        }

        $count = ($records | Where-Object {
            $_ -is [psobject] -and $_.PSObject.Properties.Match('LvaddonRoot').Count -gt 0 -and $_.LvaddonRoot -eq $lvRoot
        }).Count

        $lvaddonRoots += [pscustomobject]@{
            LvaddonRoot = $lvRoot
            InWorkspace = $inWorkspace
            Count       = $count
        }
    }
}

$summary = [pscustomobject]@{
    GeneratedAt  = (Get-Date).ToString('o')
    Root         = $root
    XCliRoot     = $xCliRoot
    DevmodeDir   = $devmodeDir
    TotalRecords = $records.Count
    ByOperation  = $byOperation
    SchemaVersions = ($records | ForEach-Object {
        if ($_ -is [psobject] -and $_.PSObject.Properties.Match('Schema').Count -gt 0) {
            $_.Schema
        } else {
            '<none>'
        }
    } | Sort-Object -Unique)
    ByRunId = $byRunId
    ConfigErrors = $configErrors
    LvaddonRoots = $lvaddonRoots
    ResourceFailures = $resourceFailures
    ToolchainFailures = $toolchainFailures
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'tests/results/_agent/icon-editor/xcli-devmode-summary.json'
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host ("[x-cli/learn] Summary written to {0}" -f $OutputPath) -ForegroundColor Cyan
