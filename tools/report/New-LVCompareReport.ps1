#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Label = ("lvcompare-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')),
  [string]$Command = "<paste command>",
  [string]$Transcript = "<path>",
  [string]$Telemetry = "<session-index path>",
  [string]$Summary = "<paste summary block>",
  [string]$Warnings = "<warnings/errors>"
)

$lines = @(
  "### LVCompare Suite (Label: $Label)",
  "- Command: ``$Command``",
  "- Summary:",
  '```',
  $Summary,
  '```',
  "- Transcript: $Transcript",
  "- Telemetry: $Telemetry",
  "- Warnings/Errors:",
  '```',
  $Warnings,
  '```'
)

$lines -join [Environment]::NewLine
