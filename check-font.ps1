<#
    Kiểm tra font có đủ glyph tiếng Việt và powerline không.

    Dùng TRƯỚC khi đổi TerminalFont trong config.ps1. Phần lớn Nerd Font
    patched bị rụng Latin Extended nên tiếng Việt ra ô vuông, mà nhìn tên
    font thì không biết được - phải tra bảng cmap.

    Usage:
        .\check-font.ps1                    # font đang dùng + các font quen thuộc
        .\check-font.ps1 -All               # mọi font mono trên máy
        .\check-font.ps1 -Name 'Hack NF'    # một font cụ thể
#>
[CmdletBinding()]
param(
    [string[]]$Name,
    [switch]$All
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName PresentationCore

. (Join-Path $PSScriptRoot 'config.ps1')

# Chữ tiếng Việt hay vỡ nhất + 2 glyph powerline oh-my-posh cần.
# Không dùng chính ký tự powerline làm key: chúng nằm trong Private Use Area,
# nhiều editor/terminal hiển thị rỗng như nhau -> PowerShell báo trùng key.
$probe = [ordered]@{
    'ô'        = 0x00F4   # o + circumflex
    'ư'        = 0x01B0   # u + horn
    'ạ'        = 0x1EA1   # a + dot below
    'ẻ'        = 0x1EBB   # e + hook above
    'Đ'        = 0x0110   # D with stroke
    'PL-sep'   = 0xE0B0   # powerline separator
    'PL-branch'= 0xE0A0   # powerline git branch
}

if (-not $Name -and -not $All) {
    $Name = @($Cfg.TerminalFont, $Cfg.EditorFont) + ($Cfg.FontFallback -split ',\s*') +
            @('CaskaydiaCove NF', 'FiraCode NF', 'JetBrainsMono NF', 'Cascadia Code', 'Consolas')
    $Name = $Name | Select-Object -Unique
}

$rows = foreach ($fam in [Windows.Media.Fonts]::SystemFontFamilies) {
    if (-not $All) {
        $match = $Name | Where-Object { $fam.Source -like "*$_*" -or $_ -like "*$($fam.Source)*" }
        if (-not $match) { continue }
    }

    $gt = $null
    foreach ($tf in $fam.GetTypefaces()) {
        $r = $null
        if ($tf.TryGetGlyphTypeface([ref]$r)) { $gt = $r; break }
    }
    if (-not $gt) { continue }

    $o = [ordered]@{ Font = $fam.Source }
    $viet = 0; $power = 0
    foreach ($k in $probe.Keys) {
        $has = $gt.CharacterToGlyphMap.ContainsKey($probe[$k])
        $o[$k] = if ($has) { 'v' } else { '-' }
        if ($has) { if ($probe[$k] -ge 0xE000) { $power++ } else { $viet++ } }
    }
    $o['Kết luận'] =
        if     ($viet -eq 5 -and $power -eq 2) { 'DÙNG ĐƯỢC' }
        elseif ($power -eq 2)                  { 'thiếu tiếng Việt' }
        elseif ($viet -eq 5)                   { 'thiếu powerline' }
        else                                   { 'thiếu cả hai' }
    [pscustomobject]$o
}

if (-not $rows) { Write-Host 'Không tìm thấy font nào khớp.' -ForegroundColor Yellow; return }

Write-Host "`nv = có glyph   - = thiếu`n" -ForegroundColor DarkGray
$rows | Sort-Object Font | Format-Table -AutoSize

Write-Host "Font đang dùng trong config.ps1 : $($Cfg.TerminalFont)" -ForegroundColor Cyan
Write-Host "Font dự phòng                   : $($Cfg.FontFallback)" -ForegroundColor Cyan
Write-Host @"

Chỉ cần font CHÍNH có powerline, còn tiếng Việt thì font dự phòng gánh được
(Windows Terminal 1.20+ hỗ trợ fallback chain). Nhưng font có sẵn cả hai thì
vẫn ngon hơn - đỡ lệch chiều rộng ký tự.
"@ -ForegroundColor DarkGray
