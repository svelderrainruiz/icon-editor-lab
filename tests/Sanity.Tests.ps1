Describe 'Repo Sanity' {
  It 'has a docs folder' {
    (Test-Path 'docs') | Should -BeTrue
  }
}
