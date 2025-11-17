#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter()][string],
    [Parameter()][string],
    [Parameter()][string],
    [Parameter()][string],
    [Parameter()][ValidateSet('32','64')][string],
    [Parameter()][string] = 'g-cli',
    [Parameter()][switch]
)

Set-StrictMode -Version Latest
Continue = 'Stop'

Write-Warning '[apply-vipc stub] Real ApplyVIPC.ps1 not vendored in this repo. '
Write-Warning ('Requested parameters: IconEditorRoot={0}, VIPCPath={1}, Toolchain={2}, LVVersion={3}, Bitness={4}' -f 
    ( ?? '<null>'), ( ?? '<null>'), ( ?? '<null>'), ( ?? '<null>'), ( ?? '<null>'))
throw 'apply-vipc stub: real automation not present. Sync icon-editor fork or vendor the action before running this workflow.'
