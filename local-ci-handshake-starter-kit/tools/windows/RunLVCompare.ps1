param(
  [string]$Left,
  [string]$Right,
  [hashtable]$Options,
  [string]$OutDir,
  [string]$Log
)
# Placeholder wrapper. Replace with real LabVIEW/LVCompare/TestStand invocation.
# Must emit standardized files into $OutDir and return a PSObject with result/duration/files.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
"Comparing `"$Left`" vs `"$Right`"" | Out-File $Log
$reportHtml = Join-Path $OutDir "report.html"
$reportJson = Join-Path $OutDir "report.json"
Set-Content $reportHtml "<html><body>Stub compare</body></html>"
Set-Content $reportJson "{""result"":""different""}"
$sw.Stop()
[pscustomobject]@{
  result = "different"
  duration_ms = $sw.ElapsedMilliseconds
  files = @{
    lvcompare_html = [IO.Path]::GetFileName($reportHtml)
    lvcompare_json = [IO.Path]::GetFileName($reportJson)
    logs = @([IO.Path]::GetFileName($Log))
  }
  error = $null
}
