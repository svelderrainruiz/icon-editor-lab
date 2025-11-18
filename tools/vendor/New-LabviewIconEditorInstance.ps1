#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Workspace = (Get-Location).Path,
    [string]$SourcePath = (Join-Path (Resolve-Path -LiteralPath (Join-Path (Get-Location).Path '..')).ProviderPath 'labview-icon-editor'),
    [string]$InstanceName,
    [switch]$ReuseExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).ProviderPath
$vendorConfigPath = Join-Path $workspaceRoot 'configs\icon-editor-vendor.json'
$existingVendorRoot = $null
if (Test-Path -LiteralPath $vendorConfigPath -PathType Leaf) {
    try {
        $existingConfig = Get-Content -LiteralPath $vendorConfigPath -Raw | ConvertFrom-Json -Depth 5
        if ($existingConfig -and $existingConfig.PSObject.Properties['vendorRoot']) {
            $rawVendorRoot = [string]$existingConfig.vendorRoot
            if (-not [string]::IsNullOrWhiteSpace($rawVendorRoot)) {
                $expandedRoot = $rawVendorRoot.Replace('${workspaceFolder}', $workspaceRoot)
                if ($expandedRoot -and (Test-Path -LiteralPath $expandedRoot -PathType Container)) {
                    $existingVendorRoot = [pscustomobject]@{
                        Raw  = $rawVendorRoot
                        Full = (Resolve-Path -LiteralPath $expandedRoot -ErrorAction Stop).ProviderPath
                    }
                }
            }
        }
    } catch {
        Write-Warning "Failed to parse vendor config at '$vendorConfigPath': $($_.Exception.Message)"
    }
}

if ($ReuseExisting -and $existingVendorRoot) {
    Write-Host "Vendor config already points to '$($existingVendorRoot.Full)'; skipping new snapshot. Run the 'Vendor: Snapshot labview-icon-editor' task to force a fresh instance."
    return
}

$instancesRoot = Join-Path $workspaceRoot 'vendor\_instances'
if (-not (Test-Path -LiteralPath $instancesRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $instancesRoot -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Source repository path '$SourcePath' not found. Clone labview-icon-editor and pass -SourcePath."
}

$timestamp = Get-Date -Format 'yyyyMMddTHHmmssZ'
$instanceName = if ($InstanceName) { $InstanceName } else { "labview-icon-editor-$timestamp" }
$instancePath = Join-Path $instancesRoot $instanceName
if (Test-Path -LiteralPath $instancePath -PathType Container) {
    throw "Vendor instance '$instancePath' already exists. Provide a unique -InstanceName."
}

Write-Host "Creating vendor instance '$instanceName' from '$SourcePath'..."
Copy-Item -Path $SourcePath -Destination $instancePath -Recurse -Force

$metadata = [ordered]@{
    sourcePath = $SourcePath
    createdAt  = (Get-Date).ToString('o')
    instance   = $instanceName
}
if (Test-Path -LiteralPath (Join-Path $SourcePath '.git')) {
    $gitInfo = git -C $SourcePath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        $metadata.sourceCommit = $gitInfo.Trim()
    }
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $instancePath 'metadata.json')

$workspaceToken = '${workspaceFolder}'
$relativeVendorRoot = "vendor/_instances/$instanceName"
$configContent = [ordered]@{
    vendorRoot = "$workspaceToken/$relativeVendorRoot"
}
$configContent | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $vendorConfigPath

Write-Host "Vendor config updated at '$vendorConfigPath'. Current instance: $instanceName"
Write-Host "Run scripts again to use the new vendor root."
