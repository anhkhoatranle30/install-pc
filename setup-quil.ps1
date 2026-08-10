<#
    Quil - terminal multiplexer sống sót qua reboot, tự resume session Claude Code.
    https://quil.cc  ·  https://github.com/artyomsv/quil

    Bản Windows là binary native (ConPTY), không cần WSL.

    Ba cái bẫy đã gặp thật, script này né sẵn:
      1. Link "latest/download/quil-windows-amd64.zip" trong docs trả 404 -
         tên asset thật có kèm số version. Phải hỏi GitHub API.
      2. Tải hỏng ra file 9 byte chứa chữ "Not Found" mà Expand-Archive vẫn
         chạy -> kiểm tra kích thước trước khi giải nén.
      3. setx cắt cụt PATH quá 1024 ký tự và trộn system PATH vào user PATH
         -> dùng [Environment]::SetEnvironmentVariable.

    Usage:
        .\setup-quil.ps1
        .\setup-quil.ps1 -Force        # cài lại kể cả khi đã có
#>
[CmdletBinding()]
param(
    [string]$InstallDir,   # để trống thì lấy từ config.ps1
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $InstallDir) { $InstallDir = $Cfg.QuilInstallDir }

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

Write-Step 'Quil'

# KHÔNG gọi `quil.exe --version` để dò: quil là ứng dụng TUI, chạy nó trong
# ngữ cảnh không có console thật (script, output bị redirect) thì nó mở TUI và
# treo vô hạn thay vì in version rồi thoát. Dò bằng file thôi.
$exe = Join-Path $InstallDir 'quil.exe'
if ((Test-Path $exe) -and -not $Force) {
    $item = Get-Item $exe
    Write-Ok "already installed: $exe"
    Write-Host ("       {0:N1} MB, {1:yyyy-MM-dd}" -f ($item.Length / 1MB), $item.LastWriteTime) -ForegroundColor DarkGray
    Write-Host '       kiểm tra version: mở terminal thật rồi gõ  quil --version' -ForegroundColor DarkGray
    Write-Host '       cài lại: .\setup-quil.ps1 -Force' -ForegroundColor DarkGray
    return
}

# ---- 1. hỏi GitHub API lấy đúng asset ------------------------------
# amd64 = x64, đúng cho mọi máy Intel/AMD 64-bit. Máy ARM (Snapdragon)
# mới cần arm64 - phát hiện qua biến môi trường kiến trúc.
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }

try {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/artyomsv/quil/releases/latest' -ErrorAction Stop
} catch {
    Write-Err "GitHub API: $($_.Exception.Message)"
    Write-Warn 'Rate-limit? Tải tay ở https://github.com/artyomsv/quil/releases/latest'
    return
}

$asset = $rel.assets | Where-Object { $_.name -like '*windows*' -and $_.name -like "*$arch*" -and $_.name -like '*.zip' } | Select-Object -First 1
if (-not $asset) {
    $asset = $rel.assets | Where-Object { $_.name -like '*windows*' -and $_.name -like '*.zip' } | Select-Object -First 1
}
if (-not $asset) {
    Write-Err "không thấy asset windows trong release $($rel.tag_name)"
    return
}
Write-Ok "release $($rel.tag_name) -> $($asset.name)"

# ---- 2. tải ---------------------------------------------------------
$zip = Join-Path $env:TEMP $asset.name
try {
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -ErrorAction Stop
} catch {
    Write-Err "tải thất bại: $($_.Exception.Message)"
    return
}

# ---- 3. xác nhận file tải về là thật --------------------------------
# Một cú 404 vẫn tạo ra file - chỉ có điều nó bé tí và chứa chữ "Not Found".
$sizeMB = [math]::Round((Get-Item $zip).Length / 1MB, 2)
if ($sizeMB -lt 1) {
    Write-Err "file tải về chỉ $sizeMB MB - hỏng (thường là 404). Đã xoá."
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    return
}
Write-Ok "downloaded $sizeMB MB"

# ---- 4. giải nén ----------------------------------------------------
try {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Expand-Archive -Path $zip -DestinationPath $InstallDir -Force -ErrorAction Stop
} catch {
    Write-Err "giải nén thất bại: $($_.Exception.Message)"
    return
}
Remove-Item $zip -Force -ErrorAction SilentlyContinue

# ---- 5. exe phải nằm thẳng trong InstallDir -------------------------
# Vài bản đóng gói lồng thêm một tầng thư mục.
Get-ChildItem $InstallDir -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -ne $InstallDir } |
    Move-Item -Destination $InstallDir -Force -ErrorAction SilentlyContinue

$found = @(Get-ChildItem $InstallDir -Filter '*.exe' -ErrorAction SilentlyContinue)
if (-not (Test-Path $exe)) {
    Write-Err "không thấy quil.exe sau khi giải nén (có: $($found.Name -join ', '))"
    return
}
Write-Ok "installed: $($found.Name -join ', ')"

# ---- 6. user PATH ---------------------------------------------------
# KHÔNG dùng setx: nó cắt cụt ở 1024 ký tự và ghi cả system PATH vào user PATH.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
    Write-Ok "thêm vào user PATH: $InstallDir"
} else {
    Write-Ok 'đã có trong user PATH'
}
# cho phiên hiện tại dùng ngay
if ($env:PATH -notlike "*$InstallDir*") { $env:PATH += ";$InstallDir" }

# ---- 7. xác nhận ----------------------------------------------------
# Lấy version từ tag của release, không gọi exe (xem ghi chú ở đầu file).
Write-Ok "quil $($rel.tag_name) -> $InstallDir"

Write-Host ''
Write-Host '  Chạy `quil` để mở TUI (tự khởi động daemon).' -ForegroundColor DarkGray
Write-Host '  Ctrl+N pane mới · Ctrl+T tab mới · F1 menu · Alt+Shift+P command palette' -ForegroundColor DarkGray
Write-Host '  Paste trong Windows Terminal: F8 hoặc Ctrl+Alt+V (Ctrl+V bị Terminal nuốt).' -ForegroundColor DarkGray
Write-Host '  Workspace lưu ở ~\.quil\ - reboot xong gõ `quil` là mọi pane quay lại.' -ForegroundColor DarkGray
Write-Host '  Phải mở lại terminal (đóng hẳn cửa sổ) thì PATH mới ăn.' -ForegroundColor DarkGray
