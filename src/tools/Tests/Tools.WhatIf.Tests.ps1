Describe "-WhatIf does not throw (non-mandatory paths)" {
  $candidates = Get-Command -CommandType Function | Where-Object {
    $_.Name -match '^(Set|New|Remove|Install|Uninstall|Publish|Enable|Disable|Start|Stop)-'
  }
  foreach ($f in $candidates) {
    $mandatory = $f.Parameters.Values | Where-Object { $_.IsMandatory }
    It "$($f.Name) supports -WhatIf without throwing" -Skip:($mandatory.Count -gt 0) {
      { & $($f.Name) -WhatIf } | Should -Not -Throw
    }
  }
}
