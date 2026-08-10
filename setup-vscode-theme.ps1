<#
    Đồng bộ màu terminal tích hợp của VS Code với Windows Terminal.

    Đọc color scheme đang dùng (config.ps1 -> ColorScheme), lấy đúng 16 màu ANSI
    của scheme đó, rồi ghi vào workbench.colorCustomizations của VS Code. Kết quả:
    terminal trong VS Code giống hệt Windows Terminal, không phải chỉnh tay.

    Màu lấy từ chính Windows Terminal:
      1. schemes tự định nghĩa trong settings.json của bạn (ưu tiên)
      2. defaults.json trong package MSIX (các scheme dựng sẵn)

    Chỉ đụng vào key workbench.colorCustomizations. Mọi key khác giữ nguyên,
    comment trong settings.json cũng giữ nguyên (không reserialize).

    Usage:
        .\setup-vscode-theme.ps1                 # theo config.ps1
        .\setup-vscode-theme.ps1 -Scheme 'Tango Dark'
        .\setup-vscode-theme.ps1 -Revert         # gỡ phần màu đã ghi
#>
[CmdletBinding()]
param(
    [string]$Scheme,
    [switch]$Revert
)

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $Scheme) { $Scheme = $Cfg.ColorScheme }

Write-Step "VS Code terminal colors <- '$Scheme'"

# ------------------------------------------------------------------
# 1. Tìm màu của scheme
# ------------------------------------------------------------------
function Get-WtScheme {
    param([string]$Name)

    # a) scheme người dùng tự định nghĩa trong settings.json
    $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $wt) {
        $raw = Get-Content $wt -Raw -Encoding UTF8
        $raw = ($raw -split "`n" | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"
        $raw = [regex]::Replace($raw, ',(\s*[}\]])', '$1')
        try {
            $hit = ($raw | ConvertFrom-Json).schemes | Where-Object { $_.name -eq $Name } | Select-Object -First 1
            if ($hit) { return $hit }
        } catch { }
    }

    # b) scheme dựng sẵn, nằm trong defaults.json của package MSIX.
    #    Thư mục có số version nên phải dò, không hardcode được.
    $pkg = Get-ChildItem 'C:\Program Files\WindowsApps' -Filter 'Microsoft.WindowsTerminal_*_x64__*' -Directory -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -First 1
    if ($pkg) {
        $def = Join-Path $pkg.FullName 'defaults.json'
        if (Test-Path $def) {
            $raw = Get-Content $def -Raw
            $raw = ($raw -split "`n" | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"
            try {
                return ($raw | ConvertFrom-Json).schemes | Where-Object { $_.name -eq $Name } | Select-Object -First 1
            } catch { }
        }
    }
    return $null
}

$s = $null
if (-not $Revert) {
    $s = Get-WtScheme $Scheme
    if (-not $s) {
        Write-Err "không tìm thấy scheme '$Scheme' trong Windows Terminal"
        Write-Host '  Xem scheme có sẵn: mở Windows Terminal -> Settings -> Color schemes' -ForegroundColor DarkGray
        return
    }
    Write-Ok "lấy được $($s.name): bg=$($s.background) fg=$($s.foreground)"
}

# ------------------------------------------------------------------
# 2. Dựng khối colorCustomizations
# ------------------------------------------------------------------
# VS Code dùng tên ANSI riêng: purple -> magenta, và có thêm ansiBrightBlack.
$map = [ordered]@{
    'terminal.background'          = $s.background
    'terminal.foreground'          = $s.foreground
    'terminalCursor.foreground'    = $s.cursorColor
    'terminal.ansiBlack'           = $s.black
    'terminal.ansiRed'             = $s.red
    'terminal.ansiGreen'           = $s.green
    'terminal.ansiYellow'          = $s.yellow
    'terminal.ansiBlue'            = $s.blue
    'terminal.ansiMagenta'         = $s.purple      # WT gọi là purple
    'terminal.ansiCyan'            = $s.cyan
    'terminal.ansiWhite'           = $s.white
    'terminal.ansiBrightBlack'     = $s.brightBlack
    'terminal.ansiBrightRed'       = $s.brightRed
    'terminal.ansiBrightGreen'     = $s.brightGreen
    'terminal.ansiBrightYellow'    = $s.brightYellow
    'terminal.ansiBrightBlue'      = $s.brightBlue
    'terminal.ansiBrightMagenta'   = $s.brightPurple
    'terminal.ansiBrightCyan'      = $s.brightCyan
    'terminal.ansiBrightWhite'     = $s.brightWhite
}

$lines = foreach ($k in $map.Keys) {
    if ($map[$k]) { '    "' + $k + '": "' + $map[$k] + '"' }
}
$block = '  "workbench.colorCustomizations": {' + "`r`n" + (($lines) -join ",`r`n") + "`r`n  },"

# ------------------------------------------------------------------
# 3. Ghi vào settings.json của VS Code
# ------------------------------------------------------------------
$f = "$env:APPDATA\Code\User\settings.json"
if (-not (Test-Path $f)) { Write-Err "không thấy $f - mở VS Code một lần rồi chạy lại"; return }

$raw = Get-Content $f -Raw -Encoding UTF8

# Kiểm tra file còn parse được trước khi đụng vào (đừng ghi đè cái mình không hiểu).
$probe = [regex]::Replace($raw, '/\*[\s\S]*?\*/', '')
$probe = ($probe -split "`n" | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"
$probe = [regex]::Replace($probe, ',(\s*[}\]])', '$1')
try { [void]($probe | ConvertFrom-Json) }
catch { Write-Err "settings.json không parse được - KHÔNG ghi gì: $($_.Exception.Message)"; return }

# Cắt bỏ khối cũ nếu có (khớp tới dấu } cùng cấp).
$pattern = '(?ms)^[ \t]*"workbench\.colorCustomizations"\s*:\s*\{.*?^[ \t]*\},?\r?\n'
$new = [regex]::Replace($raw, $pattern, '')

# Dọn dòng trống ngay sau dấu { mở đầu. Không có bước này thì mỗi lần
# revert để lại một dòng trống và apply thêm một dòng nữa - file phình
# đều đặn qua mỗi vòng chạy (đo được 4 byte/vòng trước khi sửa).
$new = [regex]::Replace($new, '\A(\s*\{)\r?\n(?:[ \t]*\r?\n)+', "`$1`r`n")

if (-not $Revert) {
    $i = $new.IndexOf('{')
    if ($i -lt 0) { Write-Err 'settings.json không có dấu {'; return }
    $new = $new.Substring(0, $i + 1) + "`r`n" + $block + $new.Substring($i + 1)
}

# Chuẩn hoá đuôi file về đúng MỘT dòng mới. Set-Content mặc định tự thêm
# một newline nữa, nên chạy nhiều lần sẽ chồng dòng trống ở cuối file và
# nó phình dần (đo được 4 byte/vòng trước khi sửa) -> phải TrimEnd và ghi
# kèm -NoNewline.
$new = $new.TrimEnd() + "`r`n"

if ($new -eq $raw) { Write-Ok 'không có gì thay đổi'; return }

Copy-Item $f "$f.bak-$stamp" -Force
Write-Host "       backup: settings.json.bak-$stamp" -ForegroundColor DarkGray
Set-Content -LiteralPath $f -Value $new -Encoding UTF8 -Force -NoNewline

if ($Revert) { Write-Ok 'đã gỡ workbench.colorCustomizations' }
else         { Write-Ok "đã ghi $(@($lines).Count) màu vào settings.json" }

Write-Host ''
Write-Host '  Terminal trong VS Code giờ giống Windows Terminal.' -ForegroundColor DarkGray
Write-Host '  Muốn EDITOR cũng cùng tông thì cài theme (colorCustomizations chỉ lo terminal):' -ForegroundColor DarkGray
Write-Host '      code --install-extension zhuangtongfa.material-theme   # One Dark Pro' -ForegroundColor DarkGray
Write-Host '  rồi Ctrl+K Ctrl+T chọn nó. Gỡ màu terminal: .\setup-vscode-theme.ps1 -Revert' -ForegroundColor DarkGray
