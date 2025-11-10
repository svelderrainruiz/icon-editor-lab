# Invoke-ProviderComparison.ps1

**Path:** `icon-editor-lab-8/tools/Vipm/Invoke-ProviderComparison.ps1`  
**Hash:** `078ccaf1c160`

## Synopsis
Compares VIPM operations across provider backends and records telemetry.

## Description
Drives scenarios (e.g. InstallVipc, BuildVip) through the VIPM provider

```
pwsh -File tools/Vipm/Invoke-ProviderComparison.ps1
pwsh -File tools/Vipm/Invoke-ProviderComparison.ps1 `
```


### Parameters
| Name | Type | Default |
|---|---|---|
| `SkipMissingProviders` |  |  |
| `Scenario` |  |  |
| `Providers` |  |  |
| `ScenarioFile` |  |  |


## Preconditions
- Ensure repo is checked out and dependencies are installed.
- If script touches LabVIEW/VIPM, verify versions via environment vars or config.

## Exit Codes
- `0` success  
- `!=0` failure

## Related
- Index: `../README.md`
