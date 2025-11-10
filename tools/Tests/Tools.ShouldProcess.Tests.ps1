Describe "Mutating functions declare SupportsShouldProcess" {
  $mutators = Get-Command -CommandType Function | Where-Object {
    $_.Name -match '^(Set|New|Remove|Install|Uninstall|Publish|Enable|Disable|Start|Stop)-'
  }
  if (-not $mutators) {
    It "No mutators found (informational)" { $true | Should -BeTrue }
  } else {
    foreach ($f in $mutators) {
      It "$($f.Name) has CmdletBinding with SupportsShouldProcess" {
        $src = $f.ScriptBlock.ToString()
        ($src -match 'CmdletBinding\s*\(\s*[^)]*SupportsShouldProcess\s*=\s*\$?true') | Should -BeTrue
      }
    }
  }
}
