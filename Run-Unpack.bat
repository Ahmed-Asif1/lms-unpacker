@echo off
setlocal DisableDelayedExpansion
if /i "%~1"=="/?" goto help
if /i "%~1"=="--help" goto help
if not "%~2"=="" (
  echo Drop one folder or ZIP at a time, or launch this file without arguments.
  pause
  exit /b 1
)
for %%F in (Start-Unpacker.ps1 LmsUnpacker.psm1 ZipIntegrity.cs) do if not exist "%~dp0%%F" goto missing
where /q pwsh.exe >nul 2>nul
if not errorlevel 1 (
  set "lms_engine=pwsh.exe"
) else (
  set "lms_engine=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)
if not exist "%lms_engine%" if not "%lms_engine%"=="pwsh.exe" goto noengine
"%lms_engine%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Unpacker.ps1" -Path "%~1"
set "lms_exit=%errorlevel%"
if not "%lms_exit%"=="0" (
  echo.
  echo The launcher reported an error. Read the message above.
  echo Open START-HERE.html or LAUNCH-HELP.txt for launch and troubleshooting steps.
)
echo.
pause
exit /b %lms_exit%

:missing
echo Some app files are missing. Extract the entire release ZIP first.
echo Keep Run-Unpack.bat, Start-Unpacker.ps1, LmsUnpacker.psm1 and ZipIntegrity.cs together.
pause
exit /b 1

:noengine
echo PowerShell was not found. This app requires Windows PowerShell 5.1 or PowerShell 7.
echo See LAUNCH-HELP.txt. A managed computer may restrict PowerShell.
pause
exit /b 1

:help
echo LMS Unpacker - quick start
echo Double-click Run-Unpack.bat, or drop one folder or ZIP onto it.
echo Read START-HERE.html for the visual tutorial.
echo If BAT files do not open, paste this command into PowerShell:
echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Unpacker.ps1"
echo This applies execution policy only to the new process; it does not change your account policy.
echo See LAUNCH-HELP.txt for other launch options.
exit /b 0
