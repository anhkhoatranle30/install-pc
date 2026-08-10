<#
    Đặt Beyond Compare 5 làm diff/merge tool mặc định cho cả git CLI và
    TortoiseGit.

    Dùng BComp.exe chứ KHÔNG phải BCompare.exe: BComp.exe chạy đồng bộ và chỉ
    thoát khi bạn đóng cửa sổ, còn BCompare.exe trả về ngay -> git tưởng bạn
    đã merge xong và ghi luôn file chưa resolve.

    Usage:
        .\setup-git-diff.ps1
        .\setup-git-diff.ps1 -SkipTortoise
#>
[CmdletBinding()]
param(
    [string]$BCompPath,
    [switch]$SkipTortoise
)

$ErrorActionPreference = 'Continue'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

Write-Step 'Beyond Compare as git diff/merge tool'

if (-not $BCompPath) {
    # winget cài Beyond Compare theo per-user scope -> nó nằm ở
    # %LOCALAPPDATA%\Programs, KHÔNG phải Program Files. Hỏi registry trước
    # thay vì đoán đường dẫn.
    $uninstall = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $BCompPath = Get-ItemProperty $uninstall -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Beyond Compare*' -and $_.InstallLocation } |
        Sort-Object DisplayVersion -Descending |
        ForEach-Object { Join-Path $_.InstallLocation 'BComp.exe' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $BCompPath) {
    $BCompPath = @(
        "$env:LOCALAPPDATA\Programs\Beyond Compare 5\BComp.exe"
        "$env:ProgramFiles\Beyond Compare 5\BComp.exe"
        "${env:ProgramFiles(x86)}\Beyond Compare 5\BComp.exe"
        "$env:LOCALAPPDATA\Programs\Beyond Compare 4\BComp.exe"
        "$env:ProgramFiles\Beyond Compare 4\BComp.exe"
        "${env:ProgramFiles(x86)}\Beyond Compare 4\BComp.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $BCompPath) {
    Write-Err 'BComp.exe not found - install Beyond Compare first'
    return
}
Write-Ok "found $BCompPath"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err 'git not on PATH'
    return
}

# git wants forward slashes in these values
$bcForGit = $BCompPath -replace '\\', '/'

# 'bc' is a mergetool git already knows how to drive; we only override the path
# so it points at 5.x instead of whatever it would guess.
$cfg = @(
    @{ K = 'diff.tool';            V = 'bc' }
    @{ K = 'difftool.bc.path';     V = $bcForGit }
    @{ K = 'difftool.prompt';      V = 'false' }
    @{ K = 'merge.tool';           V = 'bc' }
    @{ K = 'mergetool.bc.path';    V = $bcForGit }
    @{ K = 'mergetool.prompt';     V = 'false' }
    @{ K = 'mergetool.keepBackup'; V = 'false' }   # không để lại *.orig
)
foreach ($c in $cfg) {
    & git config --global $c.K $c.V
    if ($LASTEXITCODE -eq 0) { Write-Ok "$($c.K) = $($c.V)" }
    else { Write-Err "git config $($c.K) failed" }
}

Write-Host ''
Write-Host '  Dùng:  git difftool          (thay cho git diff)' -ForegroundColor DarkGray
Write-Host '         git mergetool         (khi có conflict)' -ForegroundColor DarkGray
Write-Host '         git difftool --dir-diff   so sánh cả cây thư mục' -ForegroundColor DarkGray

# ------------------------------------------------------------------
if (-not $SkipTortoise) {
Write-Step 'TortoiseGit'

    $tgKey = 'HKCU:\Software\TortoiseGit'
    if (-not (Test-Path $tgKey)) {
        Write-Warn 'TortoiseGit not installed (no HKCU\Software\TortoiseGit) - skipped'
        return
    }

    # TortoiseGit tự thay các %placeholder% trước khi gọi.
    $diffCmd  = "`"$BCompPath`" %base %mine /title1=%bname /title2=%yname"
    $mergeCmd = "`"$BCompPath`" %mine %theirs %base %merged /title1=%yname /title2=%tname /title3=%bname /title4=%mname"

    try {
        Set-ItemProperty -Path $tgKey -Name 'Diff'  -Value $diffCmd  -Type String -Force
        Set-ItemProperty -Path $tgKey -Name 'Merge' -Value $mergeCmd -Type String -Force
        Write-Ok 'TortoiseGit Diff  -> Beyond Compare'
        Write-Ok 'TortoiseGit Merge -> Beyond Compare'
        Write-Host '       (TortoiseGit -> Settings -> Diff Viewer để xem lại)' -ForegroundColor DarkGray
    } catch { Write-Err "TortoiseGit: $($_.Exception.Message)" }
}
