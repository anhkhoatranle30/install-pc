rem Run this script as admin once.

NET SESSION > NUL
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO You are NOT Administrator. Exiting...
    PING 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)

@call powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = \"tls12, tls11, tls\";iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

rem See https://developer.android.com/ndk/downloads/older_releases.html
SET ANDROID_NDK_VERSION=android-ndk-r16b
SET ANDROID_HOME=C:\Android\android-sdk
SET ANDROID_NDK_ROOT=C:\Android\android-ndk

mkdir "%ANDROID_HOME%" 1>nul 2>&1

choco install -y android-sdk
call refreshenv.cmd

REM Grant Full Controll permission for `NETWORK SERVICE` account that needs for Unity to install Android tools.
icacls "%ANDROID_HOME%" /C /T /setowner "NETWORK SERVICE"
icacls "%ANDROID_HOME%" /C /T /grant "NETWORK SERVICE":(oi)(ci)f
icacls "%ANDROID_HOME%" /C /T /inheritance:e

if not exist "%ANDROID_NDK_ROOT%" md "%ANDROID_NDK_ROOT%"

pushd "%ANDROID_NDK_ROOT%"

curl https://dl.google.com/android/repository/%ANDROID_NDK_VERSION%-windows-x86_64.zip | jar -x

setx ANDROID_HOME "%ANDROID_HOME%" /M
setx ANDROID_NDK_ROOT "%ANDROID_NDK_ROOT%" /M
setx ANDROID_NDK_HOME "%ANDROID_NDK_ROOT%\%ANDROID_NDK_VERSION%" /M

popd

psexec -accepteula -nobanner -i -u "NT AUTHORITY\NETWORK SERVICE" "%ANDROID_HOME%\tools\bin\sdkmanager.bat" tools platform-tools build-tools;30.0.2 platforms;android-29 platforms;android-30;android-31
