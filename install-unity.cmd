rem Run this script as admin.
rem See https://github.com/StephenHodgson/UnityCI/blob/master/InstallUnityHub.ps1

NET SESSION > NUL
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO You are NOT Administrator. Exiting...
    PING 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)

@call powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = \"tls12, tls11, tls\";iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

:: Install Unity using Hub
cinst -y unity-hub --ignore-checksums

pushd "%~dp0"

:: Install all Unity3D versions in unity.version file
for /f "tokens=*" %%v in (unity.version) do (
	for /f "tokens=1,2 delims=/" %%i in ("%%v") do (
		echo Installing Unity3D version %%i ^(%%j^)...
		start /wait "Installing Unity Editor..." "%ProgramFiles%\Unity Hub\Unity Hub.exe" -- --headless install --version %%i --changeset %%j
		start /wait "Installing modules..." "%ProgramFiles%\Unity Hub\Unity Hub.exe" -- --headless install-modules --version %%i -m ios -m android -m android-sdk-ndk-tools
	)
	
	rem start /wait unityhub://%%v
)

cinst -y visualstudio2017-workload-managedgame

popd