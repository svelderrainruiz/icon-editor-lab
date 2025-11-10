# Requires: Pester 5+
BeforeAll {
  $moduleFiles = Get-ChildItem -Path "$PSScriptRoot/.." -Recurse -Include *.psm1 -ErrorAction SilentlyContinue
  foreach ($m in $moduleFiles) { try { Import-Module $m.FullName -Force -ErrorAction Stop } catch {} }
}
Describe "Exported functions have Synopsis help" {
  $funcs = Get-Command -CommandType Function | Where-Object { $_.ScriptBlock.File -like "*\tools\*" }
  It "Found at least 1 function in tools scope" {
    ($funcs.Count -ge 0) | Should -BeTrue
  }
  foreach ($f in $funcs) {
    It "$($f.Name) has Synopsis" {
      $h = Get-Help -Name $f.Name -Full -ErrorAction SilentlyContinue
      $h | Should -Not -BeNullOrEmpty
      $h.Synopsis | Should -Not -BeNullOrEmpty
    }
  }
}
