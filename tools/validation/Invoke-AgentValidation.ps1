#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$PlanPath = 'configs/validation/agent-validation-plan.json',
    [string]$RepoRoot,
    [string]$SummaryPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workflowHelperPath = Join-Path $PSScriptRoot '..' 'codex' 'Invoke-XCliWorkflow.ps1'
if (-not (Test-Path -LiteralPath $workflowHelperPath -PathType Leaf)) {
    throw "Invoke-XCliWorkflow.ps1 not found at '$workflowHelperPath'."
}

$seedRoundTripScript = Join-Path $PSScriptRoot 'Test-SeedVipbRoundTrip.ps1'
if (-not (Test-Path -LiteralPath $seedRoundTripScript -PathType Leaf)) {
    throw "Seed round-trip validator not found at '$seedRoundTripScript'."
}

$operationMap = @{
    'vi-compare'    = @{ Workflow = 'vi-compare-run'; RequiresRequest = $true }
    'vi-analyzer'   = @{ Workflow = 'vi-analyzer-run'; RequiresRequest = $true }
    'vipm-apply'    = @{ Workflow = 'vipm-apply-vipc'; RequiresRequest = $true }
    'vipm-build'    = @{ Workflow = 'vipm-build-vip'; RequiresRequest = $true }
    'vipmcli-build' = @{ Workflow = 'vipmcli-build'; RequiresRequest = $true }
    'ppl-build'     = @{ Workflow = 'ppl-build'; RequiresRequest = $true }
    'seed-vipb'     = @{ Script = $seedRoundTripScript; RequiresRequest = $false }
}

$repoResolved = if ($RepoRoot) {
    (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
} else {
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..') -ErrorAction Stop).ProviderPath
}

$previousSimulationFlag = $env:ICON_EDITOR_LAB_SIMULATION
$env:ICON_EDITOR_LAB_SIMULATION = '1'

function Initialize-RequestTemplateDirectory {
    $dir = Join-Path $repoResolved '.tmp-tests' 'validation' 'requests'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}
$requestTemplateRoot = Initialize-RequestTemplateDirectory

function Resolve-RepoRelativePath {
    param([string]$PathToResolve)
    if ([string]::IsNullOrWhiteSpace($PathToResolve)) {
        return $null
    }
    $candidate = if ([System.IO.Path]::IsPathRooted($PathToResolve)) { $PathToResolve } else { Join-Path $repoResolved $PathToResolve }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
}

$tokenMap = @{
    '${workspaceFolder}' = $repoResolved
    '${repoRoot}'        = $repoResolved
}

function ConvertTo-JsonEscapedValue {
    param([string]$Value)
    if ($null -eq $Value) {
        return ''
    }
    return [System.Text.Json.JsonEncodedText]::Encode($Value).ToString()
}

function Expand-RequestTemplate {
    param(
        [string]$EntryId,
        [string]$ResolvedRequestPath
    )

    if (-not (Test-Path -LiteralPath $ResolvedRequestPath -PathType Leaf)) {
        throw "Request template not found at '$ResolvedRequestPath'."
    }

    $rawContent = Get-Content -LiteralPath $ResolvedRequestPath -Raw
    $changed = $false
    $expanded = $rawContent
    foreach ($token in $tokenMap.GetEnumerator()) {
        if ($expanded.Contains($token.Key)) {
            $expanded = $expanded.Replace($token.Key, (ConvertTo-JsonEscapedValue -Value $token.Value))
            $changed = $true
        }
    }

    if (-not $changed) {
        return $ResolvedRequestPath
    }

    $safeEntryId = if ([string]::IsNullOrWhiteSpace($EntryId)) { 'entry' } else { $EntryId.Replace('/', '_').Replace('\', '_') }
    $requestOutPath = Join-Path $requestTemplateRoot ("{0}-{1}.json" -f $safeEntryId, [Guid]::NewGuid().ToString('N'))
    Set-Content -LiteralPath $requestOutPath -Value $expanded -Encoding UTF8
    return $requestOutPath
}

function Get-EntryPropertyValue {
    param(
        $Entry,
        [string]$Name
    )
    if ($null -eq $Entry -or [string]::IsNullOrWhiteSpace($Name)) { return $null }

    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Name)) { return $Entry[$Name] }
        if ($Entry.ContainsKey($Name)) { return $Entry[$Name] }
    }

    if ($Entry.PSObject -and $Entry.PSObject.Properties.Match($Name).Count -gt 0) {
        return $Entry.$Name
    }

    return $null
}

try {
    $planResolved = Resolve-RepoRelativePath -PathToResolve $PlanPath
    if (-not (Test-Path -LiteralPath $planResolved -PathType Leaf)) {
        throw "Validation plan not found at '$planResolved'."
    }

    $planContent = Get-Content -LiteralPath $planResolved -Raw | ConvertFrom-Json -Depth 6
    if ($planContent -isnot [System.Collections.IEnumerable]) {
        $planContent = @($planContent)
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $summaryResolved = $null
    if ($SummaryPath) {
        $summaryCandidate = if ([System.IO.Path]::IsPathRooted($SummaryPath)) { $SummaryPath } else { Join-Path $repoResolved $SummaryPath }
        $summaryResolved = [System.IO.Path]::GetFullPath($summaryCandidate)
        $summaryDir = Split-Path -Parent $summaryResolved
        if (-not (Test-Path -LiteralPath $summaryDir -PathType Container)) {
            New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
        }
    } else {
        $defaultSummaryDir = Join-Path $repoResolved '.tmp-tests' 'validation'
        if (-not (Test-Path -LiteralPath $defaultSummaryDir -PathType Container)) {
            New-Item -ItemType Directory -Path $defaultSummaryDir -Force | Out-Null
        }
        $summaryResolved = Join-Path $defaultSummaryDir ("agent-validation-{0}.json" -f $timestamp)
    }

    $results = New-Object System.Collections.Generic.List[object]
    $hadFailure = $false

    foreach ($entry in $planContent) {
    $entryId = Get-EntryPropertyValue -Entry $entry -Name 'id'
    $operation = Get-EntryPropertyValue -Entry $entry -Name 'operation'
    if (-not $operation) {
        throw "Validation plan entry '$entryId' is missing the 'operation' field."
    }
    if (-not $operationMap.ContainsKey($operation)) {
        throw "Operation '$operation' in validation plan entry '$entryId' is not supported."
    }
    $workflowEntry = $operationMap[$operation]

    $description = Get-EntryPropertyValue -Entry $entry -Name 'description'
    $expectFailureValue = Get-EntryPropertyValue -Entry $entry -Name 'expectFailure'
    $continueValue = Get-EntryPropertyValue -Entry $entry -Name 'continueOnError'

    $result = [ordered]@{
        id          = $entryId
        operation   = $operation
        description = $description
        status      = 'Pending'
        startTime   = (Get-Date).ToString('o')
        endTime     = $null
        expectFailure   = [bool]$expectFailureValue
        continueOnError = [bool]$continueValue
        output      = @()
        error       = $null
    }

    $skipValue = Get-EntryPropertyValue -Entry $entry -Name 'skip'
    if ($skipValue -eq $true) {
        $result.status = 'Skipped'
        $result.endTime = (Get-Date).ToString('o')
        $results.Add($result)
        continue
    }

    $handlerType = if ($workflowEntry.ContainsKey('Workflow') -and $workflowEntry.Workflow) {
        'Workflow'
    }
    elseif ($workflowEntry.ContainsKey('Script') -and $workflowEntry.Script) {
        'Script'
    }
    else {
        throw "Validation plan entry '$entryId' references operation '$operation' without a supported handler."
    }

    $requestPathValue = Get-EntryPropertyValue -Entry $entry -Name 'requestPath'
    if ($workflowEntry.RequiresRequest -and -not $requestPathValue) {
        throw "Validation plan entry '$entryId' requires 'requestPath' for operation '$operation'."
    }

    $argumentsValue = Get-EntryPropertyValue -Entry $entry -Name 'arguments'
    $argumentList = [System.Collections.Generic.List[string]]::new()
    if ($argumentsValue) {
        if ($argumentsValue -is [System.Collections.IEnumerable] -and $argumentsValue -isnot [string]) {
            foreach ($arg in $argumentsValue) {
                if ($null -ne $arg -and $arg.ToString().Length -gt 0) {
                    $argumentList.Add([string]$arg)
                }
            }
        }
        else {
            $argumentList.Add([string]$argumentsValue)
        }
    }

    [ScriptBlock]$invoker = $null
    $displayPairs = [System.Collections.Generic.List[string]]::new()

    if ($handlerType -eq 'Workflow') {
        $helperParams = [ordered]@{
            Workflow = $workflowEntry.Workflow
        }
        if ($requestPathValue) {
            $resolvedRequest = Resolve-RepoRelativePath -PathToResolve $requestPathValue
            $helperParams['RequestPath'] = Expand-RequestTemplate -EntryId $entryId -ResolvedRequestPath $resolvedRequest
        }
        if ($argumentList.Count -gt 0) {
            $helperParams['AdditionalArgs'] = $argumentList.ToArray()
        }
        if ($repoResolved) {
            $helperParams['RepoRoot'] = $repoResolved
        }

        $invoker = { & $workflowHelperPath @helperParams }

        foreach ($pair in $helperParams.GetEnumerator()) {
            if ($pair.Key -eq 'AdditionalArgs') {
                $displayPairs.Add(("{0}=[{1}]" -f $pair.Key, ($pair.Value -join ', '))) | Out-Null
            }
            else {
                $displayPairs.Add(("{0}='{1}'" -f $pair.Key, $pair.Value)) | Out-Null
            }
        }
    }
    else {
        $scriptPath = $workflowEntry.Script
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "Script handler not found for operation '$operation' (expected at '$scriptPath')."
        }

        $scriptParams = [ordered]@{ RepoRoot = $repoResolved }
        if ($argumentList.Count -gt 0) {
            $scriptParams['Arguments'] = $argumentList.ToArray()
        }
        if ($requestPathValue) {
            $scriptParams['RequestPath'] = $requestPathValue
        }

        $invoker = { & $scriptPath @scriptParams }

        foreach ($pair in $scriptParams.GetEnumerator()) {
            if ($pair.Key -eq 'Arguments') {
                $displayPairs.Add(("{0}=[{1}]" -f $pair.Key, ($pair.Value -join ', '))) | Out-Null
            }
            else {
                $displayPairs.Add(("{0}='{1}'" -f $pair.Key, $pair.Value)) | Out-Null
            }
        }
    }

    Write-Host ("[validation] Running '{0}' with params: {1}" -f $operation, ($displayPairs -join '; '))

    $output = @()
    try {
        $output = & $invoker 2>&1
        $result.output = $output
        $result.endTime = (Get-Date).ToString('o')
        if ($expectFailureValue) {
            $result.status = 'Failed'
            $result.error  = 'Operation succeeded but failure was expected.'
            $hadFailure = $true
        } else {
            $result.status = 'Passed'
        }
    }
    catch {
        $result.output = $output
        $result.error = $_.Exception.Message
        $result.endTime = (Get-Date).ToString('o')
        if ($expectFailureValue) {
            $result.status = 'ExpectedFailure'
        } else {
            $result.status = 'Failed'
            $hadFailure = $true
        }
        if (-not $continueValue -and -not $expectFailureValue) {
            $results.Add($result)
            break
        }
    }

        $results.Add($result)
    }

    $summary = [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        planPath    = $planResolved
        repoRoot    = $repoResolved
        results     = $results
    }

    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryResolved -Encoding UTF8

    Write-Host "Validation summary written to $summaryResolved"

    if ($hadFailure) {
        throw "Agent validation detected failures. See summary at $summaryResolved."
    }
}
finally {
    if ($null -ne $previousSimulationFlag) {
        $env:ICON_EDITOR_LAB_SIMULATION = $previousSimulationFlag
    } else {
        Remove-Item -Path Env:ICON_EDITOR_LAB_SIMULATION -ErrorAction SilentlyContinue
    }
}
