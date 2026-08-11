<#
    Đặt máy không sleep + bật Remote Desktop.

    PHẦN POWER CHỈ LÀM ĐÚNG 2 MỤC có trong giao diện
    Control Panel -> Power Options -> Edit Plan Settings:

        Turn off the display:      Never
        Put the computer to sleep: Never

    Không đụng hibernate, disk timeout, giá trị pin (-dc), setting ẩn, và
    KHÔNG đụng registry driver/thiết bị. Bản trước có ghi PnPCapabilities vào
    registry card mạng - đã bỏ, vì đó là setting của DRIVER chứ không phải
    power plan, và restore power settings không gỡ được nó.

    Phần RDP chỉ sửa registry Terminal Server + bật firewall rule sẵn có của
    Windows. Không cài driver, không đụng phần cứng.

    Usage:
        .\setup-power-remote.ps1 -Check    # CHỈ XEM, không ghi gì
        .\setup-power-remote.ps1           # 2 mục power + RDP 3389
        .\setup-power-remote.ps1 -SkipRdp  # chỉ 2 mục power
        .\setup-power-remote.ps1 -SkipPower  # chỉ RDP
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    # Để trống thì lấy từ config.ps1.
    [ValidateRange(0, 65535)][int]$RdpPort = 0,
    [switch]$SkipPower,
    [switch]$SkipRdp,
    [switch]$AllowScreenOff,  # true = vẫn cho tắt màn hình
    [switch]$Check            # chỉ đọc và in ra dự định, không thay đổi gì
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
Write-Step 'Power: đúng 2 mục trong Power Options'

    # Làm ĐÚNG hai thứ mà giao diện Control Panel -> Power Options ->
    # Edit Plan Settings có, không hơn:
    #
    #     Turn off the display:      Never   -> monitor-timeout-ac 0
    #     Put the computer to sleep: Never   -> standby-timeout-ac 0
    #
    # Cố tình KHÔNG làm những thứ này (bản trước có, đã bỏ):
    #   - hibernate-timeout, disk-timeout: không có trong giao diện, không ai yêu cầu
    #   - các giá trị -dc: máy desktop không có pin, giao diện cũng không hiện
    #   - UNATTENDSLEEP: setting ẩn, chỉ cần cho RDP; ai cần thì tự bật
    #   - PnPCapabilities của card mạng: đó là setting DRIVER/thiết bị, không
    #     phải power plan. Bản trước ghi giá trị 24 vào registry card mạng dù
    #     Get-NetAdapterPowerManagement đã báo lỗi trên mọi card - đúng ra phải
    #     dừng lại. Nó cũng không bị xoá khi restore power settings, nên để lại
    #     rác mà người dùng không gỡ được bằng giao diện Power Options.
    #     Muốn tắt tiết kiệm điện cho card mạng thì làm bằng tay:
    #     Device Manager -> card -> Power Management.
    $wanted = @(
        @{ Arg = 'monitor-timeout-ac'; What = 'Turn off the display' }
        @{ Arg = 'standby-timeout-ac'; What = 'Put the computer to sleep' }
    )
    if ($AllowScreenOff) {
        $wanted = $wanted | Where-Object { $_.Arg -ne 'monitor-timeout-ac' }
        Write-Warn 'AllowScreenOff = true -> bỏ qua "Turn off the display"'
    }

    # Đọc giá trị hiện tại trước, để in được before/after và để -Check chạy
    # mà không ghi gì.
    $SUB_VIDEO = '7516b95f-f776-4464-8c53-06167f40cc99'   # Display
    $SUB_SLEEP = '238c9fa8-0aad-41ed-83f4-97be242c8f20'   # Sleep
    $VIDEOIDLE = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
    $STANDBYIDLE = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'

    function Get-AcSeconds {
        param([string]$Sub, [string]$Setting)
        $q = (& powercfg /query SCHEME_CURRENT $Sub $Setting) -join "`n"
        $m = [regex]::Match($q, 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)')
        if ($m.Success) { return [Convert]::ToInt32($m.Groups[1].Value, 16) }
        return $null
    }
    function Fmt { param($s) if ($null -eq $s) { '?' } elseif ($s -eq 0) { 'Never' } else { "$([int]($s/60)) phút" } }

    $before = [ordered]@{
        'Turn off the display'      = Get-AcSeconds $SUB_VIDEO $VIDEOIDLE
        'Put the computer to sleep' = Get-AcSeconds $SUB_SLEEP $STANDBYIDLE
    }
    Write-Host '  hiện tại:' -ForegroundColor DarkGray
    foreach ($k in $before.Keys) { Write-Host ("    {0,-26} {1}" -f $k, (Fmt $before[$k])) -ForegroundColor DarkGray }

    if ($Check) {
        Write-Host ''
        Write-Warn 'sẽ đặt về Never:'
        $wanted | ForEach-Object { Write-Host "      $($_.What)" -ForegroundColor Yellow }
        Write-Warn '-Check: KHÔNG ghi gì cả.'
    } else {
        foreach ($t in $wanted) {
            & powercfg /change $t.Arg 0 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "$($t.What) = Never" }
            else { Write-Err "powercfg /change $($t.Arg) 0 lỗi (exit $LASTEXITCODE)" }
        }

        Write-Host '  sau khi đặt:' -ForegroundColor DarkGray
        Write-Host ("    {0,-26} {1}" -f 'Turn off the display',      (Fmt (Get-AcSeconds $SUB_VIDEO $VIDEOIDLE))) -ForegroundColor DarkGray
        Write-Host ("    {0,-26} {1}" -f 'Put the computer to sleep', (Fmt (Get-AcSeconds $SUB_SLEEP $STANDBYIDLE))) -ForegroundColor DarkGray
        Write-Host '  (tương đương mở Power Options rồi chọn Never cho 2 mục đó)' -ForegroundColor DarkGray
    }
}

# ==================================================================
if (-not $SkipRdp -and $Check) {
    Write-Step "Remote Desktop (port $RdpPort) - CHỈ XEM"
    $rk = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    Write-Host ("    {0,-26} {1}" -f 'fDenyTSConnections', (Get-ItemProperty $rk -EA SilentlyContinue).fDenyTSConnections) -ForegroundColor DarkGray
    Write-Host ("    {0,-26} {1}" -f 'TermService', (Get-Service TermService -EA SilentlyContinue).Status) -ForegroundColor DarkGray
    Write-Warn '-Check: KHÔNG ghi gì cả.'
}

if (-not $SkipRdp -and -not $Check) {
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
