<#
    Cài shell cho WSL: prompt oh-my-posh + intellisense, giống bên Windows.

    Bên Linux không có PSReadLine. Tương đương gần nhất:
        zsh-autosuggestions     gợi ý xám inline từ history (mũi tên phải nhận)
        zsh-syntax-highlighting lệnh sai đổi màu đỏ ngay khi gõ
        compinit + menu select  Tab completion
        fzf                     Ctrl+R tìm history fuzzy
        oh-my-posh              đúng theme như bên Windows (config.ps1)

    Việc nặng nằm trong wsl-setup-shell.sh; file này chỉ đẩy nó vào WSL và
    chạy hai pha (pha cài gói cần root, pha cấu hình chạy dưới user của bạn).

    KHÔNG cài font trong WSL - Windows Terminal mới là cái render chữ.

    Usage:
        .\setup-wsl-shell.ps1
        .\setup-wsl-shell.ps1 -Distro Ubuntu-22.04 -PoshTheme atomic
        .\setup-wsl-shell.ps1 -Check          # chỉ xem trạng thái
#>
[CmdletBinding()]
param(
    [string]$Distro,
    [string]$PoshTheme,
    [switch]$Check
)

$ErrorActionPreference = 'Continue'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $Distro)    { $Distro    = $Cfg.WslDistro }
if (-not $PoshTheme) { $PoshTheme = $Cfg.PoshTheme }

Write-Step "WSL shell: $Distro"

# Hai loại output khác encoding nhau, đây là chỗ rất dễ sai:
#   wsl --list / --version ...  -> thông báo của CHÍNH wsl.exe, UTF-16LE
#   wsl -- <lệnh linux>         -> stdout của lệnh Linux, UTF-8
# Áp nhầm UTF-16 cho loại thứ hai thì chuỗi ra chữ Hán (2 byte ASCII bị gộp
# thành 1 ký tự CJK), áp nhầm UTF-8 cho loại thứ nhất thì có NUL xen giữa.
function Invoke-Wsl {
    param([string[]]$WslArgs, [switch]$NativeMessage)
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = if ($NativeMessage) { [Text.Encoding]::Unicode }
                                    else { [Text.UTF8Encoding]::new($false) }
        return (& wsl @WslArgs 2>&1) -join "`n"
    } finally { [Console]::OutputEncoding = $prev }
}

# ------------------------------------------------------------------
$list = Invoke-Wsl -NativeMessage @('--list', '--quiet')
if ($list -notmatch [regex]::Escape($Distro)) {
    Write-Err "chưa cài $Distro"
    Write-Host '  Chạy trước:  .\setup-wsl.ps1' -ForegroundColor Yellow
    return
}
Write-Ok "$Distro đã cài"

$user = (Invoke-Wsl @('-d', $Distro, '--', 'whoami')).Trim()
if (-not $user -or $user -match '\s') {
    Write-Err 'chưa tạo user UNIX'
    Write-Host "  Chạy:  wsl -d $Distro   (lần đầu sẽ hỏi username/password)" -ForegroundColor Yellow
    return
}
Write-Ok "user: $user"

# ------------------------------------------------------------------
# Đẩy script vào WSL. Chép qua /tmp trong chính filesystem Linux thay vì chạy
# thẳng từ /mnt/g: đường dẫn Windows mount vào WSL không giữ bit thực thi, và
# đọc qua ranh giới filesystem thì chậm.
$sh = Join-Path $PSScriptRoot 'wsl-setup-shell.sh'
if (-not (Test-Path $sh)) { Write-Err "không thấy $sh"; return }

# Đẩy nội dung qua STDIN, không qua đường dẫn.
# `wsl -- lệnh C:\duong\dan` nuốt sạch dấu backslash: wslpath nhận được
# "C:UsersCPU13387AppData..." rồi fail. Pipe stdin không dính vấn đề đó.
# `tr -d '\r'` ở đầu Linux lo luôn phần CRLF (bash báo bad interpreter: ^M).
$text = [IO.File]::ReadAllText($sh) -replace "`r`n", "`n"

$prevOut = $OutputEncoding
try {
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $text | & wsl -d $Distro -- sh -c 'tr -d "\r" > /tmp/install-pc-shell.sh'
} finally { $OutputEncoding = $prevOut }

$size = (Invoke-Wsl @('-d', $Distro, '--', 'stat', '-c', '%s', '/tmp/install-pc-shell.sh')).Trim()
if ($size -notmatch '^\d+$' -or [int]$size -lt 1000) {
    Write-Err "đẩy script thất bại (kích thước: '$size')"
    return
}
Write-Ok "đã đẩy script vào WSL ($size bytes)"

if ($Check) {
    Write-Host "`n  trạng thái trong WSL:" -ForegroundColor DarkGray
    & wsl -d $Distro -- bash /tmp/install-pc-shell.sh --check |
        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Host "`n  -Check: không thay đổi gì." -ForegroundColor DarkGray
    return
}

# ------------------------------------------------------------------
Write-Step 'Pha 1/2 - cài gói (chạy dưới root, không hỏi mật khẩu)'
& wsl -d $Distro -u root -- bash /tmp/install-pc-shell.sh --system $user
if ($LASTEXITCODE -ne 0) { Write-Err "pha system lỗi (exit $LASTEXITCODE)"; return }

Write-Step "Pha 2/2 - cấu hình cho $user"
& wsl -d $Distro -- bash /tmp/install-pc-shell.sh --user $PoshTheme
if ($LASTEXITCODE -ne 0) { Write-Err "pha user lỗi (exit $LASTEXITCODE)"; return }

# ------------------------------------------------------------------
Write-Step 'Xong'
Write-Host @"
  Mở phiên WSL MỚI để login shell zsh có hiệu lực:
      wsl -d $Distro

  Trong đó thử:
      gõ vài ký tự của lệnh cũ  -> hiện gợi ý xám, mũi tên phải để nhận
      Up / Down                 -> lọc history theo tiền tố đang gõ
      Ctrl+R                    -> tìm history fuzzy (fzf)
      Tab                       -> menu completion

  ~/.zshrc: phần giữa hai marker BEGIN/END install-pc là do script sinh, sửa
  ở ngoài thì không bị mất. Bản cũ backup thành ~/.zshrc.bak-<timestamp>.
"@ -ForegroundColor DarkGray
