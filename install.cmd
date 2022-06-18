rem Run this script as admin once.

NET SESSION > NUL
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO You are NOT Administrator. Exiting...
    PING 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)

@call powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = \"tls12, tls11, tls\";iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

cinst -y googlechrome
cinst -y notepad2-mod
cinst -y notepadplusplus.install

cinst -y git.install
cinst -y git-credential-winstore
rem cinst -y poshgit
cinst -y tortoisegit
cinst -y git-lfs
cinst -y curl
rem cinst -y curl --verison 7.52.1 && choco pin add -n=curl

cinst -y dotnet4.6.1
cinst -y msbuild.communitytasks
cinst -y msbuild.extensionpack
cinst -y openssl.light

cinst -y python2
REM Fix Python PostBuild when build iOS on Windows
if NOT exist "C:\Python27\python2.7.exe" copy "C:\Python27\python.exe" "C:\Python27\python2.7.exe"

cinst -y jre8

REM Do NOT set JAVA_HOME that cause sdkmanager.bat (require JRE8) to be failed
REM /INSTALLLEVEL=1: FeatureMain,FeatureEnvironment,FeatureJarFileRunWith (see https://chocolatey.org/packages/adoptopenjdk11openj9)
cinst -y adoptopenjdk11openj9 --params="/INSTALLLEVEL=1"
cinst -y nodist
cinst -y visualstudiocode

choco install visualstudio2022community

cinst -y rapidee
cinst -y kdiff3
cinst -y psexec --ignore-checksums

cinst -y --allowemptychecksum winrar

call refreshenv.cmd
call nodist global 12.13
call nodist npm match
call npm install --global --production bower gulp-cli npm-quick-run yarn windows-build-tools

call "%~dp0install-android.cmd"

call "%~dp0install-unity.cmd"
