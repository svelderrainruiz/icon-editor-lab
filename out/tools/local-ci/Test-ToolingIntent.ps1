[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).ProviderPath,
    [string]$RunSettingsPath = (Join-Path $RepoRoot 'tests/Pester.runsettings.psd1'),
    [string]$ConfigPath = (Join-Path $RepoRoot 'local-ci/ubuntu/config.yaml')
)
$ErrorActionPreference = 'Stop'
function Assert-FileExists {
    param([string]$Path,[string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "[$Description] Required file '$Path' not found."
    }
}
function Get-YamlObject {
    param([string]$Path)
    Assert-FileExists -Path $Path -Description 'YAML'
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        throw "[Config] python3 is required to parse YAML at $Path."
    }
    $env:LOCALCI_VALIDATE_YAML = $Path
    try {
        $pyCommand = @'
import json, os, sys
path = os.environ.get("LOCALCI_VALIDATE_YAML")
parser = None
try:
    from ruamel.yaml import YAML
    yaml = YAML(typ="safe", pure=True)
    def _parse(stream):
        return yaml.load(stream) or {}
    parser = _parse
except ImportError:
    try:
        import yaml as pyyaml
        def _parse(stream):
            return pyyaml.safe_load(stream) or {}
        parser = _parse
    except ImportError:
        print("missing-yaml-module", file=sys.stderr)
        sys.exit(1)
with open(path, "r", encoding="utf-8") as fh:
    data = parser(fh)
print(json.dumps(data))
'@
        $json = & python3 -c $pyCommand
        if ($LASTEXITCODE -ne 0) {
            throw "[Config] python3 failed to parse YAML at $Path (missing dependencies?)."
        }
    } finally {
        Remove-Item Env:LOCALCI_VALIDATE_YAML -ErrorAction SilentlyContinue | Out-Null
    }
    if (-not $json) { return @{} }
    return $json | ConvertFrom-Json
}

Assert-FileExists -Path $RunSettingsPath -Description 'Pester runsettings'
$config = Import-PowerShellDataFile -LiteralPath $RunSettingsPath
if (-not $config.ContainsKey('Run') -or -not $config.Run.Path) {
    throw '[Pester] Run.Path not defined in runsettings.'
}
$paths = @()
foreach ($entry in $config.Run.Path) {
    $full = Resolve-Path -LiteralPath (Join-Path $RepoRoot $entry) -ErrorAction SilentlyContinue
    if (-not $full) {
        throw "[Pester] Run.Path entry '$entry' does not resolve under $RepoRoot."
    }
    $paths += $full.ProviderPath
}
Write-Host "[Intent] Pester paths:"
$paths | ForEach-Object { Write-Host "  - $_" }
$tagFilters = @($config.Filter.Tag)
if ($tagFilters -and $tagFilters.Count -gt 0) {
    Write-Host "[Intent] Tag filters enabled: $($tagFilters -join ', ')"
} else {
    Write-Host '[Intent] No tag filters configured.'
}

$configObj = Get-YamlObject -Path $ConfigPath
$viCompare = $configObj.vi_compare
if ($null -eq $viCompare) {
    throw "[Config] vi_compare block missing in $ConfigPath."
}
if ($viCompare.enabled -eq $false) {
    Write-Host '[Intent] VI compare disabled via config.'
} elseif ([string]::IsNullOrWhiteSpace($viCompare.requests_template)) {
    Write-Host '[Intent] VI compare enabled with generated stub requests.'
} else {
    $templatePath = Join-Path $RepoRoot $viCompare.requests_template
    Assert-FileExists -Path $templatePath -Description 'VI compare template'
    Write-Host "[Intent] VI compare requests template: $templatePath"
}

function Test-ProviderIntent {
    param([string]$RepoRoot)
    $providersRoot = Join-Path $RepoRoot 'src/tools/providers'
    if (-not (Test-Path -LiteralPath $providersRoot)) {
        Write-Host "[Intent] Providers directory not found at $providersRoot; skipping provider checks."
        return
    }
    $providerFiles = Get-ChildItem -Path $providersRoot -Filter '*.Provider.psd1' -Recurse -ErrorAction SilentlyContinue
    if (-not $providerFiles) {
        Write-Warning "[Intent] No provider manifests (*.Provider.psd1) were discovered under $providersRoot."
        return
    }
    $testsRoot = Join-Path $RepoRoot 'tests'
    $tests = @()
    if (Test-Path -LiteralPath $testsRoot) {
        $tests = Get-ChildItem -Path $testsRoot -Recurse -Include '*.ps1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
    $tsTests = @()
    $toolsSrc = Join-Path $RepoRoot 'src/tools'
    if (Test-Path -LiteralPath $toolsSrc) {
        $tsTests = Get-ChildItem -Path $toolsSrc -Recurse -Include '*.spec.ts','*.test.ts' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
    $searchFiles = @($tests + $tsTests) | Where-Object { $_ }
    foreach ($file in $providerFiles) {
        $providerId = ($file.BaseName -replace '\.Provider$','')
        $relative = $file.FullName.Substring($RepoRoot.Length).TrimStart('\','/')
        Write-Host "[Intent] Provider manifest: $relative (id=$providerId)"
        if (-not $searchFiles) {
            Write-Warning "[Intent] No test files were discovered; unable to verify provider test coverage."
            break
        }
        $escaped = [regex]::Escape($providerId)
        $pattern = "(?i)(?<![A-Za-z0-9_])${escaped}(?![A-Za-z0-9_])"
        $hitFiles = @()
        foreach ($path in $searchFiles) {
            if (Select-String -Path $path -Pattern $pattern -Quiet) {
                $hitFiles += $path
            }
        }
        if ($hitFiles.Count -eq 0) {
            Write-Warning "[Intent] No tests reference provider '$providerId'."
        } else {
            $count = ($hitFiles | Sort-Object -Unique).Count
            Write-Host "         ↳ Referenced in $count test file(s)."
        }
    }
}

Test-ProviderIntent -RepoRoot $RepoRoot
Write-Host '[Intent] Tooling sanity checks completed successfully.'
