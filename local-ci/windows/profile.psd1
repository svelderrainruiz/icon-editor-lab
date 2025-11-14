@{
    SignRoot                = 'out'
    HarnessTags             = @('tools','scripts','smoke')
    MaxSignFiles            = 500
    TimestampTimeoutSeconds = 25
    SimulateTimestampFailure= $false
    StopOnUnstagedChanges   = $false
    DefaultSkipStages       = @()
    EnableEnvironmentParityCheck = $true
    EnvironmentProfile      = 'labview-2021-x64'
    EnvironmentProfilesPath = 'local-ci/windows/env-profiles.psd1'
    LabVIEWVersion          = 2021
    LabVIEWBitness          = 64
    EnableDevModeStage      = $true
    DevModeAction           = 'Enable' # Enable, Disable, or Skip
    DevModeVersions         = @()
    DevModeBitness          = @()
    DevModeOperation        = 'MissingInProject'
    DevModeIconEditorRoot   = 'vendor/labview-icon-editor'
    DevModeDisableAtEnd     = $true
    DevModeAllowForceClose  = $true
    AutoVendorIconEditor    = $true
    IconEditorVendorUrl     = $null
    IconEditorVendorRef     = 'develop'
    PreserveRunOnFailure    = $true
    ArchiveFailedRuns       = $true
    FailedRunArchiveRoot    = 'out/local-ci/archive'
    EnableValidationStage   = $true
    ValidationScriptPath    = 'src/tools/icon-editor/Invoke-MissingInProjectSuite.ps1'
    ValidationConfigPath    = 'src/configs/vi-analyzer/missing-in-project.viancfg'
    ValidationResultsPath   = 'tests/results'
    ValidationTestSuite     = 'compare' # compare or full
    ValidationRequireCompareReport = $true
    ValidationAdditionalArgs = @()
    EnableMipLunitStage     = $true
    MipLunitScriptPath      = 'src/tools/icon-editor/Run-MipLunit-2023x64.ps1'
    MipLunitResultsPath     = 'tests/results'
    MipLunitAnalyzerConfig  = 'src/configs/vi-analyzer/missing-in-project.viancfg'
    MipLunitAdditionalArgs  = @()
    EnableVipmStage         = $false
    VipmVipcPath            = '.github/actions/apply-vipc/runner_dependencies.vipc'
    VipmRelativePath        = 'src'
    VipmDisplayOnly         = $false
    # Default to CLI disabled; enable via LOCALCI_VICOMPARE_CLI_ENABLED=1 on
    # LabVIEW-capable self-hosted runners (for example, those labeled
    # [self-hosted, Windows, X64]) or by overriding this flag in a custom
    # profile.
    EnableViCompareCli      = $false
    ViCompareLabVIEWPath    = 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe'
    ViCompareHarnessPath    = 'src/tools/TestStand-CompareHarness.ps1'
    ViCompareMaxPairs       = 25
    ViCompareTimeoutSeconds = 900
    ViCompareNoiseProfile   = 'full'
}
