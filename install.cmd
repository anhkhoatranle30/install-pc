@echo off
setlocal

rem ============================================================
rem  Bootstrap only. All real work lives in install.ps1
rem  (the old version mixed PowerShell cmdlets into this .cmd,
rem   so half the script silently never ran).
rem  Run this as Administrator.
rem ============================================================

NET SESSION >NUL 2>&1
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO.
    ECHO   You are NOT Administrator.
    ECHO   Right-click install.cmd -^> "Run as administrator"
    ECHO.
    PAUSE
    EXIT /B 1
)

set "PS=powershell.exe"
where pwsh.exe >NUL 2>&1 && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "RC=%ERRORLEVEL%"

echo.
echo Exit code: %RC%
pause
exit /b %RC%
