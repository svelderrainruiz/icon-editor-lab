#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Label = ("missinginproject-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')),
  [string]$Command = "<paste command>",
  [string]$Transcript = "<path>",
  [string]$Summary = "<paste Pester summary>",
  [string]$Warnings = "<warnings/errors>",
  [string]$Telemetry = "<optional telemetry>"
)

$lines = @(
  "### MissingInProject Suite (Label: $Label)",
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
