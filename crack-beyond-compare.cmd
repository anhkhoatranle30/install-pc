rem Run this script as admin once.

NET SESSION > NUL
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO You are NOT Administrator. Exiting...
    PING 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)

REM code active beyond compare
#rm "$env:appdata\Scooter Software\Beyond Compare 4\*.*" -Force -Confirm
rm "$env:appdata\Scooter Software\Beyond Compare 4\BCState.xml" -Force -Confirm
rm "$env:appdata\Scooter Software\Beyond Compare 4\BCState.xml.bak" -Force -Confirm
#rm "$env:appdata\Scooter Software\Beyond Compare 4\BCSessions.xml" -Force -Confirm
#rm "$env:appdata\Scooter Software\Beyond Compare 4\BCSessions.xml.bak" -Force -Confirm
reg delete "HKCU\Software\Scooter Software\Beyond Compare 4" /v "CacheID" /f
