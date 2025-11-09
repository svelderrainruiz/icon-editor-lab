#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Label = ("host-prep-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')),
  [string]$Command = "<paste command>",
  [string]$Transcript = "<path>",
  [string]$Telemetry = "<path>",
  [string]$Summary = "<paste summary block>",
  [string]$Warnings = "<warnings/errors>"
)

$lines = @(
  "### Host Prep (Label: $Label)",
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
