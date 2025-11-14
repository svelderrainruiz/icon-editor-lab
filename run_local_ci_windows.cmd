@echo on
for %%I in (.) do set REPO=%%~fI
cd /d %REPO%
pwsh -NoLogo -NoProfile -File local-ci\windows\Invoke-LocalCI.ps1
