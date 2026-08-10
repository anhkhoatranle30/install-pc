<#
    Dọn user PATH bị hỏng.

    Triệu chứng: lệnh cài bằng winget/Store (oh-my-posh, winget, pwsh...) báo
    "not recognized" dù file có thật trên đĩa.

    Nguyên nhân: `setx PATH "%PATH%;..."`. %PATH% là PATH ĐÃ GỘP (system+user),
    nên setx chép toàn bộ system PATH vào user PATH, rồi cắt cụt ở 1024 ký tự -
    thường nuốt luôn %LOCALAPPDATA%\Microsoft\WindowsApps là nơi Windows để
    app execution alias.

    Script này:
      - bỏ mục nào user PATH có mà system PATH cũng có (thừa, không mất gì)
      - bỏ mục lặp
      - bỏ mục trỏ tới thư mục không tồn tại
      - đảm bảo có WindowsApps
      - GIỮ NGUYÊN thứ tự các mục còn lại

    Không cần admin (chỉ đụng HKCU). Mặc định chỉ xem trước.

    Usage:
        .\fix-path.ps1              # xem trước, không ghi gì
        .\fix-path.ps1 -Apply       # ghi thật (có backup)
        .\fix-path.ps1 -Restore <file>   # trả về bản backup
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$KeepMissingDirs,   # giữ cả mục trỏ tới thư mục không tồn tại
    [string]$Restore
)

$ErrorActionPreference = 'Stop'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }

$backupDir = Join-Path $env:LOCALAPPDATA 'install-pc-path-backup'

# ------------------------------------------------------------------
if ($Restore) {
    if (-not (Test-Path $Restore)) { Write-Warn "không thấy file: $Restore"; return }
    $old = (Get-Content $Restore -Raw).TrimEnd("`r", "`n")
    [Environment]::SetEnvironmentVariable('Path', $old, 'User')
    Write-Ok "đã khôi phục user PATH từ $Restore ($($old.Length) ký tự)"
    Write-Warn 'mở lại terminal để có hiệu lực'
    return
}

# ------------------------------------------------------------------
Write-Step 'Phân tích user PATH'

$rawUser = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $rawUser) { Write-Warn 'user PATH rỗng - không có gì để dọn'; return }

$sys  = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ })
$user = @($rawUser -split ';' | Where-Object { $_ })

# So sánh không phân biệt hoa thường và dấu \ cuối.
function Get-Norm { param([string]$p) $p.Trim().TrimEnd('\').ToLowerInvariant() }
$sysNorm = @($sys | ForEach-Object { Get-Norm $_ })

$windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'

$kept = @(); $seen = @{}
$dropDup = @(); $dropSys = @(); $dropGone = @()

foreach ($p in $user) {
    $k = Get-Norm $p
    if ($seen.ContainsKey($k))    { $dropDup  += $p; continue }
    if ($sysNorm -contains $k)    { $dropSys  += $p; $seen[$k] = $true; continue }
    # Thư mục không tồn tại thì bỏ, TRỪ WindowsApps (luôn giữ) - nhưng nếu
    # người dùng muốn giữ hết thì -KeepMissingDirs.
    if (-not $KeepMissingDirs -and $k -ne (Get-Norm $windowsApps) -and -not (Test-Path $p)) {
        $dropGone += $p; $seen[$k] = $true; continue
    }
    $seen[$k] = $true
    $kept += $p
}

# WindowsApps là nơi Windows để app execution alias (winget, pwsh, oh-my-posh...).
# Mất nó là hàng loạt lệnh "not recognized". Đặt lên đầu.
if (@($kept | ForEach-Object { Get-Norm $_ }) -notcontains (Get-Norm $windowsApps)) {
    $kept = @($windowsApps) + $kept
    Write-Warn 'WindowsApps bị thiếu -> thêm lại (đây là thứ làm lệnh "not recognized")'
}

$newPath = $kept -join ';'

# ------------------------------------------------------------------
Write-Host ("  trước : {0,4} mục, {1,5} ký tự" -f $user.Count, $rawUser.Length)
Write-Host ("  sau   : {0,4} mục, {1,5} ký tự" -f $kept.Count, $newPath.Length)

if ($dropSys)  { Write-Host "`n  bỏ vì system PATH đã có (không mất gì):" -ForegroundColor DarkGray
                 $dropSys  | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray } }
if ($dropDup)  { Write-Host "`n  bỏ vì lặp:" -ForegroundColor DarkGray
                 $dropDup  | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray } }
if ($dropGone) { Write-Host "`n  bỏ vì thư mục không tồn tại:" -ForegroundColor DarkGray
                 $dropGone | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray } }

Write-Host "`n  user PATH sau khi dọn:" -ForegroundColor White
$kept | ForEach-Object { Write-Host "     $_" -ForegroundColor White }

if ($rawUser -eq $newPath) { Write-Ok "`nkhông có gì để dọn"; return }

# ------------------------------------------------------------------
if (-not $Apply) {
    Write-Host ''
    Write-Warn 'Đây mới là XEM TRƯỚC - chưa ghi gì.'
    Write-Warn 'Chạy lại với  -Apply  để ghi thật (sẽ backup trước).'
    return
}

New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir ("userpath-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Set-Content -LiteralPath $backup -Value $rawUser -Encoding UTF8 -NoNewline

[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host ''
Write-Ok "đã ghi user PATH ($($kept.Count) mục)"
Write-Ok "backup: $backup"
Write-Warn 'MỞ LẠI terminal (đóng hẳn cửa sổ) thì mới có hiệu lực.'
Write-Host "  muốn quay lại:  .\fix-path.ps1 -Restore `"$backup`"" -ForegroundColor DarkGray
