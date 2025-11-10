# Tools module auto-generated (refined)
# Capture functions before loading scripts
$before = (Get-Command -CommandType Function | Select-Object -ExpandProperty Name)

# Dot-source all local .ps1 scripts
Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Compute functions added by scripts
$after = (Get-Command -CommandType Function | Select-Object -ExpandProperty Name)
$added = @($after | Where-Object { $_ -notin $before })

Export-ModuleMember -Function $added
