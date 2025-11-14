@echo off
setlocal
set "SCRIPT=%~dp0Invoke-LocalCI.ps1"
if not exist "%SCRIPT%" (
  echo Unable to locate Invoke-LocalCI.ps1 at "%SCRIPT%"
  exit /b 1
)
set "PWSH=pwsh"
where pwsh >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
  ) else if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
  ) else (
    echo pwsh not found on PATH. Install PowerShell 7 or adjust this script.
    exit /b 1
  )
)
"%PWSH%" -NoLogo -NoProfile -File "%SCRIPT%" %*
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
