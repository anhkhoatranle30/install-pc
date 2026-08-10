<#
    WSL2 + Ubuntu 22.04.

    Enables the two Windows features WSL needs, then installs the distro
    without launching it (so the script is not blocked by the interactive
    "create a UNIX username" prompt). First `wsl -d Ubuntu-22.04` from the
    user does that part.
#>
[CmdletBinding()]
param([string]$Distro = 'Ubuntu-22.04')

$ErrorActionPreference = 'Continue'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

Write-Step "WSL + $Distro"

$rebootNeeded = $false
foreach ($feature in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
    if ($state -eq 'Enabled') {
        Write-Ok "$feature already enabled"
    } else {
        $r = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
        if ($r) {
            Write-Ok "$feature enabled"
            if ($r.RestartNeeded) { $rebootNeeded = $true }
        } else {
            Write-Err "could not enable $feature"
        }
    }
}

if ($rebootNeeded) {
    Write-Warn 'Windows features were just enabled - REBOOT, then re-run:  .\install.ps1 -SkipApps -SkipTerminal'
    Write-Warn "or simply:  wsl --install -d $Distro"
    return
}

# Keep the WSL kernel current; harmless if already up to date.
& wsl --update 2>&1 | Out-String -Stream | Select-Object -Last 2 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
& wsl --set-default-version 2 2>&1 | Out-Null

$installed = @()
try {
    # wsl.exe emits UTF-16LE; decode it or every distro name comes back with NULs.
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::Unicode
    $installed = (& wsl --list --quiet) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    [Console]::OutputEncoding = $prev
} catch { }

if ($installed -contains $Distro) {
    Write-Ok "$Distro already installed"
} else {
    Write-Host "  installing $Distro (this downloads ~500 MB)..." -ForegroundColor DarkGray
    & wsl --install -d $Distro --no-launch
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$Distro installed"
        Write-Host "       run 'wsl -d $Distro' once to create your UNIX user" -ForegroundColor DarkGray
    } else {
        Write-Warn "wsl --install returned $LASTEXITCODE - trying the Store package instead"
        & winget install --id 'Canonical.Ubuntu.2204' --exact --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Distro installed via winget" }
        else { Write-Err "$Distro failed - install it manually from the Microsoft Store" }
    }
}

& wsl --set-default $Distro 2>&1 | Out-Null
