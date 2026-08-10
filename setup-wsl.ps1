<#
    WSL2 + Ubuntu 22.04.

    Enables the two Windows features WSL needs, then installs the distro
    without launching it (so the script is not blocked by the interactive
    "create a UNIX username" prompt). First `wsl -d Ubuntu-22.04` from the
    user does that part.
#>
[CmdletBinding()]
param(
    [string]$Distro,   # để trống thì lấy từ config.ps1
    [switch]$Check     # chỉ xem trạng thái, KHÔNG thay đổi gì (không cần admin)
)

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $Distro) { $Distro = $Cfg.WslDistro }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

Write-Step "WSL + $Distro"

# Script này KHÔNG BAO GIỜ tự khởi động lại máy: Enable-WindowsOptionalFeature
# luôn chạy kèm -NoRestart, và nếu Windows báo cần reboot thì script dừng lại
# ngay chứ không đi tiếp. Bạn tự chọn lúc reboot.
Write-Host '  (script này không tự restart máy - bạn tự chọn lúc reboot)' -ForegroundColor DarkGray

if (-not $isAdmin) {
    # Get-WindowsOptionalFeature cần elevation; không có quyền thì nó trả về
    # rỗng và code bên dưới sẽ tưởng feature đang tắt.
    Write-Warn 'chưa chạy với quyền Administrator - chỉ đọc được trạng thái hạn chế'
    # wsl.exe xuất UTF-16LE. Không đổi encoding thì chuỗi trả về có NUL xen
    # giữa từng ký tự và mọi phép -match đều trượt (từng báo nhầm "đã có sẵn"
    # trong khi WSL chưa hề được cài).
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $wslOut = (& wsl --version 2>&1) -join ' '
    } finally { [Console]::OutputEncoding = $prevEnc }

    if ($wslOut -match 'not installed' -or $wslOut -match 'không được cài') {
        Write-Warn 'WSL chưa được cài trên máy này'
        Write-Host '  Cần bật Windows feature -> phải chạy lại bằng Administrator.' -ForegroundColor Yellow
    } else {
        Write-Ok 'WSL đã có sẵn'
    }
    if (-not $Check) { Write-Warn 'dừng lại - mở PowerShell bằng Administrator rồi chạy lại' }
    return
}

$rebootNeeded = $false
foreach ($feature in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
    if ($state -eq 'Enabled') {
        Write-Ok "$feature already enabled"
    } elseif ($Check) {
        Write-Warn "$feature đang TẮT - bật nó sẽ cần reboot"
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

if ($Check) {
    Write-Host ''
    Write-Host '  -Check: không thay đổi gì cả.' -ForegroundColor DarkGray
    Write-Host "  Chạy thật:  .\setup-wsl.ps1     (cần Administrator)" -ForegroundColor DarkGray
    return
}

if ($rebootNeeded) {
    Write-Host ''
    Write-Warn 'Đã bật Windows feature, NHƯNG chưa có hiệu lực cho tới khi reboot.'
    Write-Warn 'Script dừng ở đây - KHÔNG tự restart. Reboot lúc nào tiện rồi chạy lại:'
    Write-Host "      .\setup-wsl.ps1" -ForegroundColor Yellow
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
