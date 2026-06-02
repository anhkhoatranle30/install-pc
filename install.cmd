rem Run this script as admin once.

NET SESSION > NUL
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO You are NOT Administrator. Exiting...
    PING 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)

@call powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = \"tls12, tls11, tls\";iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

choco install -y googlechrome
choco install -y notepad2-mod
choco install -y notepadplusplus.install

choco install -y git.install
choco install -y git-credential-winstore
rem choco install -y poshgit
choco install -y tortoisegit
choco install -y git-lfs
choco install -y curl
rem choco install -y curl --verison 7.52.1 && choco pin add -n=curl

choco install -y dotnet4.6.1
choco install -y msbuild.communitytasks
choco install -y msbuild.extensionpack
choco install -y openssl.light

choco install -y jre8

REM Do NOT set JAVA_HOME that cause sdkmanager.bat (require JRE8) to be failed
REM /INSTALLLEVEL=1: FeatureMain,FeatureEnvironment,FeatureJarFileRunWith (see https://chocolatey.org/packages/adoptopenjdk11openj9)
choco install -y adoptopenjdk11openj9 --params="/INSTALLLEVEL=1"
choco install -y visualstudiocode

choco install -y visualstudio2019community
choco install -y postman
choco install -y mongodb
choco install -y mongodb-compass
choco install -y nodejs --version 16.20.0
choco install -y 7zip
choco install -y unikey
choco install -y microsoft-teams
choco install -y skype
choco install -y zoom
choco install -y totalcommander
choco install -y lightshot
choco install -y treesizefree

choco install -y rapidee
choco install -y psexec --ignore-checksums

choco install -y --allowemptychecksum winrar

choco install -y kdiff3

@REM Install WinMerge
winget install -e --id WinMerge.WinMerge --accept-source-agreements --accept-package-agreements

set "WINMERGE_PATH=C:\Program Files\WinMerge\WinMergeU.exe"
if not exist "%WINMERGE_PATH%" (
    set "WINMERGE_PATH=C:\Program Files (x86)\WinMerge\WinMergeU.exe"
)
if not exist "%WINMERGE_PATH%" (
    echo [LOI] Khong tim thay WinMergeU.exe. Vui long kiem tra duong dan.
    pause
    exit /b 1
)
echo Tim thay WinMerge tai: %WINMERGE_PATH%

git config --global diff.tool winmerge
git config --global difftool.winmerge.cmd "\"%WINMERGE_PATH%\" -e -u -dl \"Base\" -dr \"Mine\" \"$LOCAL\" \"$REMOTE\""
git config --global difftool.prompt false

git config --global merge.tool winmerge
git config --global mergetool.winmerge.cmd "\"%WINMERGE_PATH%\" -e -u -dl \"Local\" -dm \"Base\" -dr \"Remote\" \"$LOCAL\" \"$BASE\" \"$REMOTE\" -o \"$MERGED\""
git config --global mergetool.winmerge.trustExitCode true
git config --global mergetool.prompt false
@REM End installing WinMerge


@REM customized terminal
choco install -y microsoft-windows-terminal
winget install --accept-package-agreements oh-my-posh
winget install --accept-package-agreements XP8K0HKJFRXGCK
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Terminal-Icons -Repository PSGallery -Force
@REM Copy this value to `$PROFILE `: oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Invoke-Expression
ECHO "Read code (above line) to copy value to $PROFILE file"
notepad $PROFILE
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
ECHO "Download CaskaydiaCove Nerd Font -> Install -> Set terminal font to it"
ECHO "Download Fira Code -> Install -> Set Visual Studio font to it"

@REM Intellisense in Terminal
Install-Module -Name PSReadLine -force

@REM call refreshenv.cmd

call "%~dp0install-android.cmd"

call "%~dp0install-unity.cmd"
