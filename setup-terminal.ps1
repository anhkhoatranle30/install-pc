<#
    Terminal / editor configuration.

    Everything the old install.cmd asked you to paste into notepad by hand
    is written programmatically here:
      * PowerShell $PROFILE   (oh-my-posh prompt, Terminal-Icons, PSReadLine intellisense)
      * Windows Terminal settings.json  (font, default profile, opacity)
      * VS Code settings.json (font + ligatures)
      * cmd.exe autocomplete via Clink
      * "Open with Code" right-click context menu

    Safe to re-run. Existing files are backed up as *.bak-<timestamp> and
    our block is replaced between the BEGIN/END markers instead of appended.
#>
[CmdletBinding()]
param(
    # Để trống thì lấy từ config.ps1. Truyền vào đây chỉ để thử tạm.
    [string]$TerminalFont,
    [string]$EditorFont,
    [string]$FontFallback,
    [string]$PoshTheme,
    # Mặc định KHÔNG đè key đã có trong settings.json của VS Code (có thể là
    # bạn tự chỉnh). Bật cờ này để ép chúng khớp config.ps1.
    [switch]$UpdateVsCode
)

$ErrorActionPreference = 'Continue'

# Sở thích nằm ở config.ps1 - xem file đó, không sửa ở đây.
. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $TerminalFont) { $TerminalFont = $Cfg.TerminalFont }
if (-not $EditorFont)   { $EditorFont   = $Cfg.EditorFont }
if (-not $FontFallback) { $FontFallback = $Cfg.FontFallback }
if (-not $PoshTheme)    { $PoshTheme    = $Cfg.PoshTheme }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

function Backup-File {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
        Write-Host "       backup: $(Split-Path -Leaf $Path).bak-$stamp" -ForegroundColor DarkGray
    }
}

function Read-JsonFile {
<#
    Reads a .json/.jsonc file, tolerating // and /* */ comments and trailing
    commas (VS Code and Windows Terminal both accept those; ConvertFrom-Json
    does not).

    Returns $null when the file is absent or empty - meaning "safe to create".
    THROWS when the file exists but cannot be parsed, so callers abort instead
    of overwriting a config they failed to understand.
#>
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

    $raw = [regex]::Replace($raw, '/\*[\s\S]*?\*/', '')                  # block comments
    $raw = ($raw -split "`n" | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"  # whole-line // (leaves "http://" alone)
    $raw = [regex]::Replace($raw, ',(\s*[}\]])', '$1')                   # trailing commas

    try { return $raw | ConvertFrom-Json }
    catch { throw "cannot parse $Path : $($_.Exception.Message)" }
}

function Test-JsonHasKey {
    <# Top-level key lookup on raw JSON text, so we never have to reserialize. #>
    param([string]$Text, [string]$Key)
    return $Text -match ('(?m)^\s*"' + [regex]::Escape($Key) + '"\s*:')
}

function Set-JsonProperty {
    <# Sets $Object.$Name = $Value on a PSCustomObject, adding the member if missing. #>
    param($Object, [string]$Name, $Value)
    if ($Object.PSObject.Properties.Name -contains $Name) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

# ==================================================================
Write-Step 'PowerShell modules'
# ==================================================================
try {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    Set-ExecutionPolicy -Scope CurrentUser  -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    Write-Ok 'ExecutionPolicy = RemoteSigned'
} catch { Write-Warn "ExecutionPolicy: $($_.Exception.Message)" }

try {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Write-Ok 'NuGet provider + trusted PSGallery'
} catch { Write-Warn "PSGallery: $($_.Exception.Message)" }

foreach ($m in 'PSReadLine', 'Terminal-Icons', 'posh-git') {
    try {
        # -SkipPublisherCheck is required for PSReadLine: Windows ships a signed
        # copy and the gallery build has a different publisher.
        Install-Module -Name $m -Scope AllUsers -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
        Write-Ok "module $m"
    } catch { Write-Warn "module $m : $($_.Exception.Message)" }
}

# ==================================================================
Write-Step 'PowerShell $PROFILE'
# ==================================================================
$beginMarker = '# ===== BEGIN install-pc ====='
$endMarker   = '# ===== END install-pc ====='

$profileBody = @"
$beginMarker
# Generated by install-pc / setup-terminal.ps1 - edit above or below this block,
# anything BETWEEN the markers is overwritten on the next run.

# --- UTF-8 so Vietnamese text is not mangled ----------------------------
[Console]::OutputEncoding = [Text.UTF8Encoding]::new(`$false)
[Console]::InputEncoding  = [Text.UTF8Encoding]::new(`$false)
`$OutputEncoding           = [Text.UTF8Encoding]::new(`$false)

# --- Oh My Posh prompt -------------------------------------------------
# Đổi theme: sửa `$PoshTheme bên dưới. Xem 122 theme có sẵn bằng:
#     Get-ChildItem `$env:POSH_THEMES_PATH -Filter *.omp.json | % { `$_.BaseName }
# Xem trước tất cả: https://ohmyposh.dev/docs/themes
`$PoshTheme = '$PoshTheme'

# Cài qua winget/Store thì oh-my-posh là gói MSIX, themes nằm trong thư mục
# có kèm số version (…\WindowsApps\ohmyposh.cli_30.6.2.0_x64__…\themes), nên
# phải dò chứ không hardcode được - đường dẫn đổi sau mỗi lần update.
`$poshThemes = `$env:POSH_THEMES_PATH
if (-not (`$poshThemes -and (Test-Path `$poshThemes))) {
    `$poshThemes = @(
        "`$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
        "`$env:LOCALAPPDATA\oh-my-posh\themes"
    ) | Where-Object { Test-Path `$_ } | Select-Object -First 1
}
if (-not `$poshThemes) {
    `$poshThemes = Get-ChildItem 'C:\Program Files\WindowsApps' -Filter 'ohmyposh.cli_*' -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path `$_.FullName 'themes' } |
        Where-Object { Test-Path `$_ } | Select-Object -First 1
}
if (`$poshThemes) { `$env:POSH_THEMES_PATH = `$poshThemes }

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    `$themeFile = if (`$poshThemes) { Join-Path `$poshThemes "`$PoshTheme.omp.json" }
    if (`$themeFile -and (Test-Path `$themeFile)) { oh-my-posh init pwsh --config `$themeFile | Invoke-Expression }
    else                                          { oh-my-posh init pwsh | Invoke-Expression }
}

# --- Icons in ls / dir -------------------------------------------------
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# --- Intellisense: inline suggestion + dropdown list --------------------
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -EditMode Windows
    # Predictive intellisense needs three things, and throws loudly if any is
    # missing:
    #   - PSReadLine 2.2+            (Windows ships 2.0 in-box)
    #   - PowerShell 7.2+            for the 'Plugin' source specifically
    #   - a real, non-redirected console with virtual terminal support
    # That last one is why a plain 'powershell -Command ...' from a script used
    # to fill the screen with red - guard it rather than let it fail.
    `$canPredict = (Get-Module PSReadLine).Version -ge [version]'2.2.0' -and
                  -not [Console]::IsOutputRedirected -and
                  `$Host.Name -eq 'ConsoleHost'
    if (`$canPredict) {
        try {
            if (`$PSVersionTable.PSVersion -ge [version]'7.2') {
                Set-PSReadLineOption -PredictionSource HistoryAndPlugin
            } else {
                Set-PSReadLineOption -PredictionSource History
            }
            Set-PSReadLineOption -PredictionViewStyle ListView
            Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
        } catch { }
    }
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 10000
    Set-PSReadLineOption -Colors @{ InlinePrediction = '#6b7280' }

    Set-PSReadLineKeyHandler -Key Tab          -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow      -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow    -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key RightArrow   -Function ForwardWord      # accept one word of the suggestion
    Set-PSReadLineKeyHandler -Key 'Ctrl+d'     -Function DeleteChar
    Set-PSReadLineKeyHandler -Key 'Alt+Enter'  -Function AddLine
}

# --- git helpers --------------------------------------------------------
Import-Module posh-git -ErrorAction SilentlyContinue

# --- Native argument completers ----------------------------------------
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param(`$wordToComplete, `$commandAst, `$cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = `$OutputEncoding = [Text.Utf8Encoding]::new()
        winget complete --word="`$wordToComplete" --commandline "`$(`$commandAst.ToString())" --position `$cursorPosition |
            ForEach-Object { [Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_) }
    }
}
`$chocoProfile = "`$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path `$chocoProfile) { Import-Module `$chocoProfile }

# --- Nạp lại PATH mà không phải mở terminal mới -------------------------
# Biến môi trường chỉ áp cho tiến trình MỚI. Sau khi cài gì đó hoặc chạy
# fix-path.ps1, shell đang mở vẫn giữ PATH cũ - gõ  reload-path  là xong.
# Với quil thì phải chạy  quil restart : pane do daemon sinh ra nên chúng
# thừa kế môi trường của daemon, không phải của pane hiện tại.
# (Không dùng dấu backtick trong comment: trong here-string sinh ra file này,
#  backtick-r là escape của carriage return và sẽ cắt đôi dòng comment.)
function reload-path {
    `$env:PATH = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
    Write-Host "PATH nạp lại: `$((`$env:PATH -split ';' | Where-Object { `$_ }).Count) mục" -ForegroundColor Green
}
Set-Alias refreshenv reload-path

# --- Cách ĐÚNG để thêm thư mục vào PATH ---------------------------------
function Add-UserPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]`$Directory)

    `$dir = (Resolve-Path `$Directory -ErrorAction SilentlyContinue)?.Path
    if (-not `$dir) { Write-Warning "không có thư mục: `$Directory"; return }

    `$cur = [Environment]::GetEnvironmentVariable('Path','User')
    if ((`$cur -split ';' | ForEach-Object { `$_.TrimEnd('\').ToLower() }) -contains `$dir.TrimEnd('\').ToLower()) {
        Write-Host "đã có trong user PATH: `$dir" -ForegroundColor DarkGray
        return
    }
    [Environment]::SetEnvironmentVariable('Path', "`$cur;`$dir", 'User')
    reload-path
    Write-Host "đã thêm vào user PATH: `$dir" -ForegroundColor Green
}

# --- Chặn setx phá PATH -------------------------------------------------
# setx PATH "%PATH%;..." là cái bẫy: %PATH% là PATH ĐÃ GỘP system+user, nên
# setx chép cả system PATH vào user PATH rồi cắt cụt ở 1024 ký tự. Máy này
# từng mất WindowsApps và .local\bin vì đúng lỗi đó.
# Hàm này chỉ chặn khi đụng PATH; mọi biến khác vẫn chạy setx thật.
# Cần dùng setx thật cho PATH: gõ  setx.exe  (có đuôi .exe) để bỏ qua hàm này.
function setx {
    `$real = Join-Path `$env:SystemRoot 'System32\setx.exe'
    if (`$args.Count -gt 0 -and `$args[0] -match '^(?i)path`$') {
        Write-Host ''
        Write-Warning 'ĐỪNG dùng setx cho PATH - nó sẽ cắt cụt ở 1024 ký tự và trộn system PATH vào user PATH.'
        Write-Host '  Dùng thay thế:  Add-UserPath "C:\thu\muc"' -ForegroundColor Yellow
        Write-Host '  Cố tình vẫn muốn: setx.exe PATH "..."' -ForegroundColor DarkGray
        Write-Host '  PATH lỡ hỏng rồi: G:\install-pc\fix-path.ps1' -ForegroundColor DarkGray
        return
    }
    & `$real @args
}

# --- Aliases ------------------------------------------------------------
Set-Alias ll  Get-ChildItem
Set-Alias grep Select-String
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function which (`$name) { (Get-Command `$name -ErrorAction SilentlyContinue).Source }

$endMarker
"@

# Both hosts: pwsh 7 and Windows PowerShell 5.1. Use the real Documents
# folder so OneDrive redirection is handled.
$docs = [Environment]::GetFolderPath('MyDocuments')
$profilePaths = @(
    Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
    Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
)

foreach ($p in $profilePaths) {
    try {
        $dir = Split-Path -Parent $p
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        if (Test-Path -LiteralPath $p) {
            Backup-File $p
            $existing = Get-Content -LiteralPath $p -Raw
            if (-not $existing) { $existing = '' }
            # Plain index surgery, not regex replace: the profile body is full of
            # $ and \ that a regex replacement string would mangle.
            $i0 = $existing.IndexOf($beginMarker)
            $i1 = $existing.IndexOf($endMarker)
            $new = if ($i0 -ge 0 -and $i1 -gt $i0) {
                       $existing.Substring(0, $i0) + $profileBody + $existing.Substring($i1 + $endMarker.Length)
                   } else {
                       $existing.TrimEnd() + "`r`n`r`n" + $profileBody
                   }
        } else {
            $new = $profileBody
        }
        Set-Content -LiteralPath $p -Value $new -Encoding UTF8 -Force
        Write-Ok "profile: $p"
    } catch { Write-Err "profile $p : $($_.Exception.Message)" }
}

# ==================================================================
Write-Step 'Windows Terminal settings'
# ==================================================================
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtFound = $false
foreach ($wt in $wtPaths) {
    if (-not (Test-Path -LiteralPath $wt)) { continue }
    $wtFound = $true
    try {
        Backup-File $wt
        $wtJson = Read-JsonFile $wt
        if (-not $wtJson) { Write-Warn "skip $wt (unreadable)"; continue }

        if (-not $wtJson.profiles) { Set-JsonProperty $wtJson 'profiles' ([pscustomobject]@{}) }
        if (-not $wtJson.profiles.defaults) { Set-JsonProperty $wtJson.profiles 'defaults' ([pscustomobject]@{}) }

        $d = $wtJson.profiles.defaults
        # Comma-separated fallback chain (Windows Terminal 1.20+). Nerd Font
        # patched builds carry the powerline glyphs but routinely drop Latin
        # Extended, so Vietnamese (ô ư ạ ẻ) renders as tofu unless a font that
        # actually has those glyphs backs it up.
        Set-JsonProperty $d 'font' ([pscustomobject]@{
            face = "$TerminalFont, $FontFallback"
            size = $Cfg.TerminalFontSize
        })
        Set-JsonProperty $d 'colorScheme'    $Cfg.ColorScheme
        Set-JsonProperty $d 'useAcrylic'     $Cfg.UseAcrylic
        Set-JsonProperty $d 'opacity'        $Cfg.Opacity
        Set-JsonProperty $d 'padding'        $Cfg.Padding
        Set-JsonProperty $d 'cursorShape'    $Cfg.CursorShape
        Set-JsonProperty $d 'scrollbarState' $Cfg.ScrollbarState

        # Default to PowerShell 7 if its profile exists - oh-my-posh looks best there.
        # WT only materialises that profile the first time it starts AFTER pwsh
        # is installed, so on a fresh run the list may not have it yet.
        if ($Cfg.DefaultToPwsh) {
            $pwshProfile = $wtJson.profiles.list | Where-Object {
                $_.source -eq 'Windows.Terminal.PowershellCore' -or
                $_.commandline -match 'pwsh' -or
                $_.name -eq 'PowerShell'
            } | Select-Object -First 1
            if ($pwshProfile) {
                Set-JsonProperty $wtJson 'defaultProfile' $pwshProfile.guid
                Write-Ok 'default profile -> PowerShell 7'
            } else {
                Write-Warn 'PowerShell 7 profile not in Windows Terminal yet - open WT once, then re-run setup-terminal.ps1'
            }
        }

        Set-JsonProperty $wtJson 'copyOnSelect' $Cfg.CopyOnSelect

        $wtJson | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $wt -Encoding UTF8 -Force
        Write-Ok "Windows Terminal font -> $TerminalFont"
    } catch { Write-Err "Windows Terminal: $($_.Exception.Message)" }
}
if (-not $wtFound) {
    Write-Warn 'Windows Terminal settings.json not found - launch Windows Terminal once, then re-run: .\install.ps1 -SkipApps'
}

# ==================================================================
Write-Step 'VS Code settings'
# ==================================================================
# A hand-tuned settings.json is full of comments and personal preferences that
# ConvertTo-Json would silently destroy. So: only ADD keys that are missing,
# by splicing text in after the opening brace. Existing keys are never touched.
$codeSettings = "$env:APPDATA\Code\User\settings.json"
# Ghép font chính + fallback, bỏ trùng - nếu font chính đã nằm sẵn trong
# danh sách fallback thì không liệt kê hai lần.
function Join-FontList {
    param([string]$Primary, [string]$Fallback, [string[]]$Tail)
    $names = @($Primary) + ($Fallback -split ',') + $Tail |
             ForEach-Object { $_.Trim() } | Where-Object { $_ }
    ($names | Select-Object -Unique) -join ', '
}

$codeWanted = [ordered]@{
    'editor.fontFamily'                  = Join-FontList $EditorFont   $Cfg.FontFallback @('monospace')
    'editor.fontLigatures'               = $Cfg.VsCodeLigatures
    'editor.fontSize'                    = $Cfg.EditorFontSize
    'terminal.integrated.fontFamily'     = Join-FontList $TerminalFont $Cfg.FontFallback
}

function ConvertTo-JsonValue {
    # ConvertTo-Json mã hoá dấu nháy đơn thành ' - hợp lệ nhưng xấu và khó
    # đọc trong settings.json. Tự encode cho gọn.
    param($v)
    if ($v -is [bool])   { return $v.ToString().ToLower() }
    if ($v -is [int] -or $v -is [double]) { return "$v" }
    return '"' + ($v -replace '\\', '\\\\' -replace '"', '\"') + '"'
}
try {
    $dir = Split-Path -Parent $codeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (-not (Test-Path -LiteralPath $codeSettings)) {
        # Fresh machine - safe to write the whole thing.
        ([pscustomobject]$codeWanted | ConvertTo-Json -Depth 32) |
            Set-Content -LiteralPath $codeSettings -Encoding UTF8 -Force
        Write-Ok "VS Code settings created (font $EditorFont)"
    } else {
        $raw    = Get-Content -LiteralPath $codeSettings -Raw -Encoding UTF8
        $parsed = Read-JsonFile $codeSettings   # throws -> we abort before touching anything

        $missing = @($codeWanted.Keys | Where-Object { -not (Test-JsonHasKey $raw $_) })
        $present = @($codeWanted.Keys | Where-Object { Test-JsonHasKey $raw $_ })
        # Khác giá trị config = hoặc bạn tự sửa, hoặc là giá trị cũ script ghi
        # từ lần trước. Không phân biệt được nên KHÔNG tự đè - chỉ báo ra.
        $stale   = @($present | Where-Object { "$($parsed.$_)" -ne "$($codeWanted[$_])" })

        $new = $raw
        if ($missing) {
            $insert = ($missing | ForEach-Object {
                '  "' + $_ + '": ' + (ConvertTo-JsonValue $codeWanted[$_]) + ','
            }) -join "`r`n"
            $i = $new.IndexOf('{')
            $new = $new.Substring(0, $i + 1) + "`r`n" + $insert + $new.Substring($i + 1)
        }
        if ($stale -and $UpdateVsCode) {
            foreach ($k in $stale) {
                $pattern = '("' + [regex]::Escape($k) + '"\s*:\s*)("(?:[^"\\]|\\.)*"|true|false|-?[\d.]+)'
                $repl    = '${1}' + (ConvertTo-JsonValue $codeWanted[$k]).Replace('$', '$$')
                $new     = [regex]::Replace($new, $pattern, $repl, 1)
            }
        }

        if ($new -ne $raw) {
            Backup-File $codeSettings
            Set-Content -LiteralPath $codeSettings -Value $new -Encoding UTF8 -Force
        }

        if ($missing) { Write-Ok "VS Code: added $($missing -join ', ')" }
        if ($stale -and $UpdateVsCode) { Write-Ok "VS Code: updated $($stale -join ', ')" }
        if (-not $missing -and -not ($stale -and $UpdateVsCode)) { Write-Ok 'VS Code: nothing to add' }

        foreach ($k in $present) {
            if ($stale -contains $k -and -not $UpdateVsCode) {
                Write-Warn "VS Code '$k' = '$($parsed.$k)' (config muốn '$($codeWanted[$k])') - dùng -UpdateVsCode để đổi"
            } elseif ($stale -notcontains $k) {
                Write-Host "       '$k' đã khớp config" -ForegroundColor DarkGray
            }
        }
    }
} catch {
    Write-Err "VS Code settings LEFT UNTOUCHED: $($_.Exception.Message)"
}

# ==================================================================
Write-Step 'VS Code right-click context menu'
# ==================================================================
function Add-VsCodeContextMenu {
    $code = @(
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
        "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $code) { Write-Warn 'Code.exe not found - skipping context menu'; return }

    # Go through the .NET registry API, NOT the PowerShell registry provider.
    # The "all file types" key is literally named "*", and New-Item -Path
    # 'HKCR:\*\shell\VSCode' makes the provider treat it as a wildcard and
    # enumerate every class in the hive - it hangs for minutes and creates
    # nothing. The .NET API takes the name literally.
    $entries = @(
        @{ Sub = '*\shell\VSCode';                    Arg = '%1' }   # a file
        @{ Sub = 'Directory\shell\VSCode';            Arg = '%V' }   # a folder
        @{ Sub = 'Directory\Background\shell\VSCode'; Arg = '%V' }   # empty space in a folder
    )
    foreach ($e in $entries) {
        $key = $null; $cmd = $null
        try {
            $key = [Microsoft.Win32.Registry]::ClassesRoot.CreateSubKey($e.Sub)
            $key.SetValue('', 'Open w&ith Code')            # '' = the (Default) value
            $key.SetValue('Icon', "$code,0")
            $cmd = $key.CreateSubKey('command')
            $cmd.SetValue('', "`"$code`" `"$($e.Arg)`"")
        } finally {
            if ($cmd) { $cmd.Dispose() }
            if ($key) { $key.Dispose() }
        }
    }
    Write-Ok 'Open with Code (files, folders, folder background)'
}
try { Add-VsCodeContextMenu } catch { Write-Err "context menu: $($_.Exception.Message)" }

# ==================================================================
Write-Step 'cmd.exe autocomplete (Clink)'
# ==================================================================
# cmd.exe has no native intellisense. Clink injects readline into it:
# history search, inline suggestions and Tab completion.
# clink installs into a version-numbered subfolder (…\clink\1.9.31\clink.bat),
# so search rather than guess, and prefer the highest version found.
$clink = @("$env:ProgramFiles\clink", "${env:ProgramFiles(x86)}\clink", 'C:\tools\clink') |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ -Recurse -Filter 'clink.bat' -ErrorAction SilentlyContinue } |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName

if ($clink) {
    try {
        & $clink autorun install | Out-Null
        # Inline fish-style suggestion from history - the actual "intellisense"
        # bit. Only exists in clink-maintained (1.x), not the dead 0.4.9 build.
        & $clink set autosuggest.enable true            2>&1 | Out-Null
        & $clink set history.dupe_mode erase_prev       2>&1 | Out-Null
        & $clink set match.expand_abbrev true           2>&1 | Out-Null
        Write-Ok "Clink autorun enabled ($clink)"
    } catch { Write-Warn "clink autorun: $($_.Exception.Message)" }
} else {
    Write-Warn 'clink not found - cmd.exe stays without autocomplete'
}

# ==================================================================
Write-Step 'Font check'
# ==================================================================
$installed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties.Name
foreach ($f in @($TerminalFont, $EditorFont)) {
    if ($installed -match [regex]::Escape($f.Split(' ')[0])) { Write-Ok "font present: $f" }
    else { Write-Warn "font '$f' not detected. Run: oh-my-posh font install CascadiaCode" }
}
