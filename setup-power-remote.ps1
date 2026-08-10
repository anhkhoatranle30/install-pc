<#
    Keep the PC awake + let Remote Desktop in.

    Needed together: an RDP box that falls asleep is an RDP box you cannot
    reach. Windows also has a *second*, hidden sleep timer ("unattended sleep")
    that fires after a remote session disconnects even when the normal
    standby timeout is 0 - that one is the usual reason a machine still
    vanishes an hour after you disconnect.

    Usage:
        .\setup-power-remote.ps1                 # no-sleep + RDP on 3389
        .\setup-power-remote.ps1 -RdpPort 13389  # non-default port
        .\setup-power-remote.ps1 -SkipRdp        # only the power settings
        .\setup-power-remote.ps1 -SkipPower      # only RDP
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    # Để trống thì lấy từ config.ps1.
    [ValidateRange(0, 65535)][int]$RdpPort = 0,
    [switch]$SkipPower,
    [switch]$SkipRdp,
    [switch]$AllowScreenOff   # let the display still switch off
)

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'config.ps1')
if ($RdpPort -eq 0)     { $RdpPort = $Cfg.RdpPort }
if (-not $AllowScreenOff) { $AllowScreenOff = [bool]$Cfg.AllowScreenOff }

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }

# ==================================================================
if (-not $SkipPower) {
Write-Step 'Power: never sleep'

    # ac = plugged in, dc = on battery. 0 = never.
    $timeouts = @(
        @{ Arg = 'standby-timeout-ac';   Value = 0; What = 'sleep (plugged in)' }
        @{ Arg = 'standby-timeout-dc';   Value = 0; What = 'sleep (battery)' }
        @{ Arg = 'hibernate-timeout-ac'; Value = 0; What = 'hibernate (plugged in)' }
        @{ Arg = 'hibernate-timeout-dc'; Value = 0; What = 'hibernate (battery)' }
        @{ Arg = 'disk-timeout-ac';      Value = 0; What = 'disk spindown (plugged in)' }
    )
    if (-not $AllowScreenOff) {
        $timeouts += @{ Arg = 'monitor-timeout-ac'; Value = 0; What = 'display off (plugged in)' }
    }

    foreach ($t in $timeouts) {
        & powercfg /change $t.Arg $t.Value 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "$($t.What) = never" }
        else { Write-Err "powercfg /change $($t.Arg) failed ($LASTEXITCODE)" }
    }

    # The one the Settings UI does not show you. Without this the box sleeps
    # ~2 min after an RDP session drops, no matter what the above says.
    $SUB_SLEEP     = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
    $UNATTENDSLEEP = '7bc4a2f9-d8fc-4469-b07b-33eb785aaca0'
    & powercfg /setacvalueindex SCHEME_CURRENT $SUB_SLEEP $UNATTENDSLEEP 0 2>&1 | Out-Null
    & powercfg /setdcvalueindex SCHEME_CURRENT $SUB_SLEEP $UNATTENDSLEEP 0 2>&1 | Out-Null
    & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
    Write-Ok 'unattended sleep timeout = never  (the RDP-disconnect killer)'

    # NICs are allowed to power down by default; that drops the box off the
    # network even while it is technically awake.
    #
    # Get/Set-NetAdapterPowerManagement throws "A device attached to the system
    # is not functioning" on plenty of real drivers that simply do not expose
    # the WMI power class, so drive it through the adapter's class registry key
    # instead. PnPCapabilities bit 0x8 = "don't let the computer turn this off",
    # bit 0x10 = "don't let it wake the computer"; 24 (0x18) sets both.
    $netClass = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
    $physical = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)
    if (-not $physical) { Write-Warn 'no physical network adapters found' }

    foreach ($nic in $physical) {
        # Only touch physical NICs - never the ZeroTier / WSL / Hyper-V virtual ones.
        $key = Get-ChildItem $netClass -ErrorAction SilentlyContinue |
               Where-Object {
                   (Get-ItemProperty $_.PSPath -Name NetCfgInstanceId -ErrorAction SilentlyContinue).NetCfgInstanceId -eq $nic.InterfaceGuid
               } | Select-Object -First 1

        if (-not $key) { Write-Warn "no registry key for NIC '$($nic.Name)'"; continue }

        try {
            $cur = (Get-ItemProperty $key.PSPath -Name PnPCapabilities -ErrorAction SilentlyContinue).PnPCapabilities
            if ($cur -eq 24) {
                Write-Ok "NIC power saving already off: $($nic.Name)"
            } else {
                Set-ItemProperty -Path $key.PSPath -Name PnPCapabilities -Value 24 -Type DWord -Force
                Write-Ok "NIC stays powered: $($nic.Name)  (was '$cur', now 24 - applies after adapter restart)"
            }
        } catch { Write-Warn "NIC '$($nic.Name)': $($_.Exception.Message)" }
    }

    Write-Host "`n  Current effective timeouts:" -ForegroundColor DarkGray
    (& powercfg /query SCHEME_CURRENT $SUB_SLEEP) -join "`n" |
        Select-String -Pattern 'GUID Alias|Current AC Power Setting Index' -AllMatches |
        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
}

# ==================================================================
if (-not $SkipRdp) {
Write-Step "Remote Desktop (port $RdpPort)"

    $tsKey  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $rdpKey = "$tsKey\WinStations\RDP-Tcp"

    try {
        # 0 = allow connections
        Set-ItemProperty -Path $tsKey -Name 'fDenyTSConnections' -Value 0 -Type DWord -Force
        Write-Ok 'RDP connections allowed'

        # Network Level Authentication ON. Do not turn this off - it is what
        # forces authentication before a session is created.
        Set-ItemProperty -Path $rdpKey -Name 'UserAuthentication' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $rdpKey -Name 'SecurityLayer'      -Value 2 -Type DWord -Force
        Write-Ok 'Network Level Authentication enforced'

        $current = (Get-ItemProperty -Path $rdpKey -Name 'PortNumber' -ErrorAction SilentlyContinue).PortNumber
        if ($current -ne $RdpPort) {
            Set-ItemProperty -Path $rdpKey -Name 'PortNumber' -Value $RdpPort -Type DWord -Force
            Write-Ok "listening port $current -> $RdpPort  (reboot or restart TermService to apply)"
        } else {
            Write-Ok "listening port $RdpPort"
        }
    } catch { Write-Err "registry: $($_.Exception.Message)" }

    # Service must be up and set to start with Windows.
    try {
        Set-Service -Name TermService -StartupType Automatic -ErrorAction Stop
        if ((Get-Service TermService).Status -ne 'Running') { Start-Service TermService -ErrorAction Stop }
        Write-Ok 'TermService running / automatic'
    } catch { Write-Warn "TermService: $($_.Exception.Message)" }

    # Firewall: built-in group covers 3389; a custom port needs its own rule.
    try {
        Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction Stop
        Write-Ok 'firewall group "Remote Desktop" enabled'
    } catch { Write-Warn "firewall group: $($_.Exception.Message)" }

    if ($RdpPort -ne 3389) {
        foreach ($proto in 'TCP', 'UDP') {
            $name = "RDP-Custom-$proto-$RdpPort"
            try {
                Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
                New-NetFirewallRule -Name $name -DisplayName "Remote Desktop ($proto $RdpPort)" `
                    -Direction Inbound -Action Allow -Protocol $proto -LocalPort $RdpPort `
                    -Profile Domain,Private -ErrorAction Stop | Out-Null
                Write-Ok "firewall rule $name (Domain+Private only)"
            } catch { Write-Err "firewall rule $name : $($_.Exception.Message)" }
        }
    }

    # ---------- how to connect ----------
    Write-Step 'Connect with'
    $me = "$env:USERDOMAIN\$env:USERNAME"
    Write-Host "  User      : $me" -ForegroundColor White
    Write-Host "  Computer  : $env:COMPUTERNAME" -ForegroundColor White

    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
        ForEach-Object {
            $tag = if ($_.InterfaceAlias -match 'ZeroTier') { '  <- use this one from outside the LAN' } else { '' }
            $addr = if ($RdpPort -eq 3389) { $_.IPAddress } else { "$($_.IPAddress):$RdpPort" }
            Write-Host ("  {0,-9} : {1}{2}" -f $_.InterfaceAlias.Substring(0, [Math]::Min(9, $_.InterfaceAlias.Length)), $addr, $tag) -ForegroundColor White
        }

    Write-Host ''
    # Nói chính xác phạm vi: group "Remote Desktop" dựng sẵn của Windows là
    # profile=Any (mở trên cả Public). Chỉ rule TỰ TẠO cho port khác 3389 mới
    # bị giới hạn Domain+Private.
    if ($RdpPort -eq 3389) {
        Write-Warn 'Group "Remote Desktop" dựng sẵn mở trên MỌI profile, kể cả Public.'
    } else {
        Write-Warn "Rule tự tạo cho port $RdpPort chỉ mở Domain+Private."
    }
    Write-Warn 'Đừng port-forward RDP ra internet - vào qua IP ZeroTier.'

    # Đây là nguyên nhân số 1 làm RDP không vào được dù mọi thứ khác đã đúng:
    # LimitBlankPasswordUse=1 (mặc định) chặn logon QUA MẠNG với account
    # password rỗng, mà RDP chính là logon qua mạng.
    $me = Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue
    if ($me -and -not $me.PasswordRequired) {
        Write-Err "Account '$($me.Name)' có PasswordRequired=False -> RDP sẽ KHÔNG vào được."
        Write-Host '       Đặt password rồi thử lại:  net user ' -NoNewline -ForegroundColor Yellow
        Write-Host "$($me.Name) *" -ForegroundColor Yellow
    } else {
        Write-Warn 'Account phải có password; account password rỗng không RDP được.'
    }
}
