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

cinst -y jre8

REM Do NOT set JAVA_HOME that cause sdkmanager.bat (require JRE8) to be failed
REM /INSTALLLEVEL=1: FeatureMain,FeatureEnvironment,FeatureJarFileRunWith (see https://chocolatey.org/packages/adoptopenjdk11openj9)
cinst -y adoptopenjdk11openj9 --params="/INSTALLLEVEL=1"
cinst -y visualstudiocode

cinst -y visualstudio2019community
cinst -y postman
cinst -y mongodb
cinst -y mongodb-compass
cinst -y nodejs --version 16.20.0
cinst -y 7zip
cinst -y unikey
cinst -y microsoft-teams
cinst -y skype
cinst -y zoom
cinst -y totalcommander
cinst -y lightshot

cinst -y rapidee
cinst -y kdiff3
cinst -y psexec --ignore-checksums

REM beyond compare
cinst -y beyondcompare --version=4.4.6.27483
REM code active beyond compare
#rm "$env:appdata\Scooter Software\Beyond Compare 4\*.*" -Force -Confirm
rm "$env:appdata\Scooter Software\Beyond Compare 4\BCState.xml" -Force -Confirm
rm "$env:appdata\Scooter Software\Beyond Compare 4\BCState.xml.bak" -Force -Confirm
#rm "$env:appdata\Scooter Software\Beyond Compare 4\BCSessions.xml" -Force -Confirm
#rm "$env:appdata\Scooter Software\Beyond Compare 4\BCSessions.xml.bak" -Force -Confirm
reg delete "HKCU\Software\Scooter Software\Beyond Compare 4" /v "CacheID" /f

cinst -y --allowemptychecksum winrar

REM customized terminal
cinst -y microsoft-windows-terminal
winget install oh-my-posh
winget install XP8K0HKJFRXGCK
Install-Module -Name Terminal-Icons -Repository PSGallery -Force
notepad $PROFILE
$notePath = "C:\noteterminal.txt"
Set-Content -Path $notePath -Value "Copy this value to `$PROFILE `: oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Invoke-Expression"
notepad $notePath
REM NerdFont
git clone https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
.\install.ps1
REM powerline font 
git clone https://github.com/powerline/fonts.git
cd fonts
.\install.ps1

call refreshenv.cmd

call "%~dp0install-android.cmd"

call "%~dp0install-unity.cmd"
