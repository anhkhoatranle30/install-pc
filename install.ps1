#Requires -RunAsAdministrator
<#
    New-PC setup.
    Entry point is install.cmd (bootstrap + admin check).

    Usage:
        .\install.ps1                 # everything
        .\install.ps1 -OnlyTerminal   # pretty prompt + intellisense only, no other apps
        .\install.ps1 -SkipApps       # only terminal config + driver check
        .\install.ps1 -SkipWsl        # skip the WSL/Ubuntu step (needs reboot)
        .\install.ps1 -OnlyDrivers    # just the motherboard/driver warning
#>
[CmdletBinding()]
param(
    [switch]$SkipApps,
    [switch]$SkipTerminal,
    [switch]$SkipWsl,
    [switch]$OnlyDrivers,
    [switch]$OnlyTerminal
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# ------------------------------------------------------------------
# Fonts used everywhere. Change here, not in 5 different places.
# ------------------------------------------------------------------
# JetBrainsMono NF is the only patched Nerd Font of the usual suspects that
# carries BOTH the powerline glyphs oh-my-posh needs AND full Vietnamese.
# Verified per-glyph: CaskaydiaCove NF has no Latin Extended at all, and
# FiraCode NF has "o" but not "u-horn" / "a-dot-below".
$Global:TerminalFont = 'JetBrainsMono NF'
$Global:EditorFont   = 'JetBrainsMono NF'

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
$Global:Results = [System.Collections.Generic.List[object]]::new()

function Write-Step { param([string]$Text) Write-Host "`n=== $Text ===" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "  [ ok ] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  [warn] $Text" -ForegroundColor Yellow }
function Write-Err  { param([string]$Text) Write-Host "  [fail] $Text" -ForegroundColor Red }

function Add-Result {
    param([string]$Name, [string]$Status, [string]$Detail = '')
    $Global:Results.Add([pscustomobject]@{ App = $Name; Status = $Status; Detail = $Detail })
}

# winget exit codes that really mean "fine, nothing to do"
$Global:WingetOkCodes = @(
    0,
    -1978335189,  # 0x8A15002B no applicable upgrade found (already latest)
    -1978335135,  # 0x8A150061 package already installed
    -1978334967,  # 0x8A150109 reboot required to finish
    -1978335216   # 0x8A150010 already installed / no applicable installer
)

function Install-App {
<#
    Installs one app. Tries winget first, falls back to chocolatey.
    Never throws - records the outcome and moves on, so one bad package
    does not abort the whole machine setup.
#>
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$WingetId,
        [string]$ChocoId,
        [string]$ChocoParams,
        [string[]]$WingetExtraArgs = @(),
        [string[]]$ChocoExtraArgs  = @()
    )

    Write-Host "  -> $Name" -ForegroundColor DarkGray

    if ($WingetId -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        $argList = @(
            'install', '--id', $WingetId, '--exact',
            '--silent', '--accept-package-agreements', '--accept-source-agreements',
            '--disable-interactivity'
        ) + $WingetExtraArgs
        & winget @argList 2>&1 | Out-String -Stream | Where-Object { $_ -match '\S' } | Select-Object -Last 3 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -in $Global:WingetOkCodes) {
            Write-Ok $Name; Add-Result $Name 'ok' 'winget'; return
        }
        Write-Warn "$Name : winget failed (code $LASTEXITCODE)"
    }

    if ($ChocoId -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        $argList = @('install', $ChocoId, '-y', '--no-progress', '--limit-output') + $ChocoExtraArgs
        if ($ChocoParams) { $argList += "--params=$ChocoParams" }
        & choco @argList | Select-Object -Last 3 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -in 0, 1641, 3010) {
            Write-Ok "$Name (choco)"; Add-Result $Name 'ok' 'choco'; return
        }
        Write-Err "$Name : choco failed (code $LASTEXITCODE)"
        Add-Result $Name 'FAILED' "choco exit $LASTEXITCODE"
        return
    }

    Write-Err "$Name : no working installer"
    Add-Result $Name 'FAILED' 'no installer'
}

function Initialize-PackageManagers {
    Write-Step 'Package managers'

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host '  installing Chocolatey...' -ForegroundColor DarkGray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:PATH += ";$env:ALLUSERSPROFILE\chocolatey\bin"
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) { Write-Ok "Chocolatey $(choco --version)" }
    else { Write-Err 'Chocolatey not available' }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Ok "winget $(winget --version)"
        & winget source update --disable-interactivity 2>&1 | Out-Null
    } else {
        Write-Warn 'winget not found - install "App Installer" from the Microsoft Store; falling back to choco'
    }
}

# ==================================================================
#  MAIN
# ==================================================================
Write-Host @"

  ____  ____    ____       _
 |  _ \/ ___|  / ___|  ___| |_ _   _ _ __
 | |_) \___ \  \___ \ / _ \ __| | | | '_ \
 |  __/ ___) |  ___) |  __/ |_| |_| | |_) |
 |_|   |____/  |____/ \___|\__|\__,_| .__/
                                    |_|
"@ -ForegroundColor Cyan

if ($OnlyDrivers) {
    & "$root\check-drivers.ps1"
    return
}

if (-not $SkipApps) {
    Initialize-PackageManagers
}

# -OnlyTerminal installs just the terminal stack and skips every other
# section, so re-running on an already-set-up PC touches nothing else.
if (-not $SkipApps -and -not $OnlyTerminal) {

    # ---------------------------------------------------------------
    Write-Step 'Browsers & basics'
    Install-App 'Google Chrome'  -WingetId 'Google.Chrome'          -ChocoId 'googlechrome'
    Install-App '7-Zip'          -WingetId '7zip.7zip'              -ChocoId '7zip'
    Install-App 'WinRAR'         -WingetId 'RARLab.WinRAR'          -ChocoId 'winrar' -ChocoExtraArgs @('--allow-empty-checksums')
    Install-App 'Notepad++'      -WingetId 'Notepad++.Notepad++'    -ChocoId 'notepadplusplus.install'
    Install-App 'Notepad2-mod'                                      -ChocoId 'notepad2-mod'
    Install-App 'Total Commander' -WingetId 'Ghisler.TotalCommander' -ChocoId 'totalcommander'
    Install-App 'Lightshot'                                         -ChocoId 'lightshot'
    Install-App 'TreeSize Free'  -WingetId 'JAMSoftware.TreeSize.Free' -ChocoId 'treesizefree'
    Install-App 'UniKey'                                            -ChocoId 'unikey'
    Install-App 'RapidEE'                                           -ChocoId 'rapidee'
    Install-App 'PsExec'                                            -ChocoId 'psexec' -ChocoExtraArgs @('--ignore-checksums')

    # ---------------------------------------------------------------
    Write-Step 'Git & diff tools'
    Install-App 'Git'            -WingetId 'Git.Git'                -ChocoId 'git.install'
    Install-App 'Git LFS'        -WingetId 'GitHub.GitLFS'          -ChocoId 'git-lfs'
    Install-App 'TortoiseGit'    -WingetId 'TortoiseGit.TortoiseGit' -ChocoId 'tortoisegit'
    Install-App 'WinMerge'       -WingetId 'WinMerge.WinMerge'      -ChocoId 'winmerge'
    Install-App 'KDiff3'         -WingetId 'KDE.KDiff3'             -ChocoId 'kdiff3'

    # ---------------------------------------------------------------
    Write-Step 'Dev runtimes & CLI'
    Install-App 'Node.js (latest)' -WingetId 'OpenJS.NodeJS'        -ChocoId 'nodejs'
    Install-App 'Python 3'       -WingetId 'Python.Python.3.13'     -ChocoId 'python'
    Install-App 'OpenJDK 11'                                        -ChocoId 'adoptopenjdk11openj9' -ChocoParams '/INSTALLLEVEL=1'
    Install-App 'Java Runtime 8'                                    -ChocoId 'jre8'
    Install-App 'OpenSSL (light)'                                   -ChocoId 'openssl.light'
    Install-App 'curl'           -WingetId 'cURL.cURL'              -ChocoId 'curl'

    # PuTTY ships puttygen.exe + pageant.exe + plink.exe in the same package
    Install-App 'PuTTY (+ PuTTYgen)' -WingetId 'PuTTY.PuTTY'        -ChocoId 'putty.install'

    # ---------------------------------------------------------------
    Write-Step 'Editors & IDE'
    # Choco's vscode package adds the "Open with Code" context menu by default;
    # Add-VsCodeContextMenu (setup-terminal.ps1) repairs it if winget was used.
    Install-App 'Visual Studio Code' -WingetId 'Microsoft.VisualStudioCode' `
        -WingetExtraArgs @('--scope','machine','--override','/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath') `
        -ChocoId 'visualstudiocode' -ChocoParams '/NoDesktopIcon'

    # Visual Studio removed on purpose - Unity Hub installs the VS/build tools it needs.
    Install-App 'Unity Hub'      -WingetId 'Unity.UnityHub'         -ChocoId 'unity-hub'

    # ---------------------------------------------------------------
    Write-Step 'Claude'
    Install-App 'Claude Desktop' -WingetId 'Anthropic.Claude'
    Install-App 'Claude Code CLI' -WingetId 'Anthropic.ClaudeCode'

    # ---------------------------------------------------------------
    Write-Step 'Work apps'
    Install-App 'Microsoft Teams' -WingetId 'Microsoft.Teams'       -ChocoId 'microsoft-teams'
    Install-App 'Zoom'           -WingetId 'Zoom.Zoom'              -ChocoId 'zoom'
    Install-App 'Postman'        -WingetId 'Postman.Postman'        -ChocoId 'postman'
    Install-App 'MongoDB'                                           -ChocoId 'mongodb'
    Install-App 'MongoDB Compass' -WingetId 'MongoDB.Compass.Full'  -ChocoId 'mongodb-compass'
}

# ---------------------------------------------------------------
if (-not $SkipApps -and -not $OnlyTerminal) {
    Write-Step 'Remote access'
    Install-App 'ZeroTier One' -WingetId 'ZeroTier.ZeroTierOne'     -ChocoId 'zerotier-one'
    Install-App 'Parsec'       -WingetId 'Parsec.Parsec'            -ChocoId 'parsec'
}

# ---------------------------------------------------------------
if (-not $SkipApps) {
    Write-Step 'Terminal stack'
    # PowerShell 7 lives here, not with the dev runtimes: oh-my-posh and
    # PSReadLine predictions are the reason we want it.
    Install-App 'PowerShell 7'   -WingetId 'Microsoft.PowerShell'   -ChocoId 'powershell-core'
    Install-App 'Windows Terminal' -WingetId 'Microsoft.WindowsTerminal' -ChocoId 'microsoft-windows-terminal'
    Install-App 'Oh My Posh'     -WingetId 'JanDeDobbeleer.OhMyPosh'
    # clink-maintained (1.x), NOT 'clink' - that package is the abandoned
    # 0.4.9 build from 2015 and has no inline autosuggest.
    Install-App 'Clink (cmd.exe autocomplete)'                      -ChocoId 'clink-maintained'
    Install-App "$Global:TerminalFont"                              -ChocoId 'cascadia-code-nerd-font'
    Install-App "$Global:EditorFont"                                -ChocoId 'firacodenf'
    # Nerd Font patched builds of Cascadia/Fira drop Latin Extended, so
    # Vietnamese renders as tofu. JetBrains Mono carries the full set and is
    # used as the fallback face in Windows Terminal.
    Install-App 'JetBrainsMono Nerd Font' -WingetId 'DEVCOM.JetBrainsMonoNerdFont'
}

# ---------------------------------------------------------------
if (-not $SkipApps -and -not $SkipWsl -and -not $OnlyTerminal) { & "$root\setup-wsl.ps1" }

if (-not $SkipTerminal) { & "$root\setup-terminal.ps1" }

# ---------------------------------------------------------------
if (-not $OnlyTerminal -and -not $SkipPowerRemote) { & "$root\setup-power-remote.ps1" -RdpPort $RdpPort }

# ------------------------------------------------------------------
Write-Step 'Summary'
if ($Global:Results.Count) {
    $Global:Results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    $failed = @($Global:Results | Where-Object Status -eq 'FAILED')
    if ($failed.Count) {
        Write-Warn "$($failed.Count) package(s) failed - install those manually:"
        $failed | ForEach-Object { Write-Host "        $($_.App)  ($($_.Detail))" -ForegroundColor Yellow }
    } else {
        Write-Ok 'All packages installed.'
    }
}

# ------------------------------------------------------------------
# Always last: the driver nag. Blocking popup so it cannot be missed.
# -OnlyTerminal is a targeted re-run, so skip it there.
if (-not $OnlyTerminal) { & "$root\check-drivers.ps1" }

Write-Host "`nDone. Close and reopen Windows Terminal to see the new prompt." -ForegroundColor Cyan
Write-Host "A reboot is recommended (WSL + PATH changes).`n" -ForegroundColor Cyan
