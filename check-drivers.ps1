<#
    Motherboard / driver reminder.

    Detects the board, BIOS and GPUs, prints them, then shows a TopMost popup
    with the exact vendor download page so nobody forgets to update chipset /
    LAN / audio drivers on a fresh install. The popup is modal but times out,
    so an unattended install cannot hang on it.

    Standalone:
        powershell -ExecutionPolicy Bypass -File .\check-drivers.ps1
        .\check-drivers.ps1 -NoPopup      # console only, for logs
        .\check-drivers.ps1 -TimeoutSeconds 0   # wait for an answer for ever
#>
[CmdletBinding()]
param(
    [switch]$NoPopup,
    [switch]$OpenBrowser,          # skip the Yes/No question, just open the pages
    [int]$TimeoutSeconds = 120     # auto-answer "Later" after this long; 0 = never
)

$ErrorActionPreference = 'Continue'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# ------------------------------------------------------------------
# Hardware facts
# ------------------------------------------------------------------
$board = Get-CimInstance Win32_BaseBoard      -ErrorAction SilentlyContinue
$sys   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios  = Get-CimInstance Win32_BIOS           -ErrorAction SilentlyContinue
$gpus  = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)

$boardVendor  = ($board.Manufacturer, $sys.Manufacturer | Where-Object { $_ } | Select-Object -First 1)
$boardModel   = ($board.Product,      $sys.Model        | Where-Object { $_ } | Select-Object -First 1)
$biosVersion  = $bios.SMBIOSBIOSVersion
$biosDate     = if ($bios.ReleaseDate) { ([datetime]$bios.ReleaseDate).ToString('yyyy-MM-dd') } else { 'unknown' }
$serial       = $bios.SerialNumber
if ($serial -in 'Default string', 'To Be Filled By O.E.M.', 'System Serial Number', '') { $serial = $null }

$biosAgeDays  = if ($bios.ReleaseDate) { [int]((Get-Date) - [datetime]$bios.ReleaseDate).TotalDays } else { $null }

# ------------------------------------------------------------------
# Vendor -> support page. OEM prebuilts (Dell/HP/Lenovo) can be looked up
# by service tag / serial, so build the deep link when we have one.
# ------------------------------------------------------------------
function Get-VendorSupportUrl {
    param([string]$Vendor, [string]$Model, [string]$Serial)

    $m = [uri]::EscapeDataString(($Model -replace '\s+', ' ').Trim())

    switch -Regex ($Vendor) {
        'gigabyte'          { return "https://www.gigabyte.com/Search?kw=$m" }
        'asus|asustek'      { return "https://www.asus.com/support/Download-Center/?keyword=$m" }
        'micro-star|msi'    { return "https://www.msi.com/search/$m" }
        'asrock'            { return "https://www.asrock.com/support/index.asp?cat=Download" }
        'biostar'           { return "https://www.biostar.com.tw/app/en/support/download.php" }
        'dell|alienware'    {
            if ($Serial) { return "https://www.dell.com/support/home/en-us/product-support/servicetag/$Serial/drivers" }
            return 'https://www.dell.com/support/home/en-us?app=drivers'
        }
        'hewlett|hp '       {
            if ($Serial) { return "https://support.hp.com/us-en/drivers/selfservice/swdetails?sku=$Serial" }
            return 'https://support.hp.com/us-en/drivers'
        }
        'lenovo'            {
            if ($Serial) { return "https://pcsupport.lenovo.com/us/en/products/$Serial/downloads" }
            return 'https://pcsupport.lenovo.com/us/en/downloads'
        }
        'acer'              { return 'https://www.acer.com/us-en/support/drivers-and-manuals' }
        'intel'             { return 'https://www.intel.com/content/www/us/en/download-center/home.html' }
        'supermicro'        { return 'https://www.supermicro.com/en/support/resources/downloadcenter' }
        'framework'         { return 'https://knowledgebase.frame.work/bios-and-drivers-downloads-rJ3PaCexh' }
        default             { return "https://www.google.com/search?q=$([uri]::EscapeDataString("$Vendor $Model drivers download"))" }
    }
}

function Get-GpuDriverUrl {
    param([string]$GpuName)
    switch -Regex ($GpuName) {
        'nvidia|geforce|quadro|rtx|gtx' { 'https://www.nvidia.com/Download/index.aspx' }
        'amd|radeon'                    { 'https://www.amd.com/en/support' }
        'intel'                         { 'https://www.intel.com/content/www/us/en/support/products/80939/graphics.html' }
        default                         { $null }
    }
}

$boardUrl = Get-VendorSupportUrl -Vendor $boardVendor -Model $boardModel -Serial $serial
$gpuLinks = [ordered]@{}
foreach ($g in $gpus) {
    $u = Get-GpuDriverUrl $g.Name
    if ($u -and -not $gpuLinks.Contains($g.Name)) { $gpuLinks[$g.Name] = $u }
}

# ------------------------------------------------------------------
# Console report
# ------------------------------------------------------------------
Write-Step 'DRIVER UPDATE CHECK'
Write-Host ''
Write-Host ('  {0,-16}{1}' -f 'Motherboard:', "$boardVendor $boardModel") -ForegroundColor White
Write-Host ('  {0,-16}{1}' -f 'BIOS:',        "$biosVersion  ($biosDate)") -ForegroundColor White
if ($serial) { Write-Host ('  {0,-16}{1}' -f 'Serial/Tag:', $serial) -ForegroundColor White }
foreach ($g in $gpus) { Write-Host ('  {0,-16}{1}' -f 'GPU:', "$($g.Name)  driver $($g.DriverVersion)") -ForegroundColor White }
Write-Host ''
Write-Host "  Board drivers : $boardUrl" -ForegroundColor Yellow
foreach ($k in $gpuLinks.Keys) { Write-Host "  GPU drivers   : $($gpuLinks[$k])" -ForegroundColor Yellow }

if ($null -ne $biosAgeDays -and $biosAgeDays -gt 365) {
    Write-Host "`n  ! BIOS is $biosAgeDays days old - check for a newer version." -ForegroundColor Red
}

# ------------------------------------------------------------------
# Popup
# ------------------------------------------------------------------
if ($NoPopup) { return }

$lines = @(
    'Windows Update does NOT ship motherboard chipset, LAN, audio or BIOS updates.'
    'Install them from the vendor before using this PC.'
    ''
    "Motherboard : $boardVendor $boardModel"
    "BIOS        : $biosVersion  ($biosDate)"
)
if ($serial) { $lines += "Serial/Tag  : $serial" }
foreach ($g in $gpus) { $lines += "GPU         : $($g.Name)" }
if ($null -ne $biosAgeDays -and $biosAgeDays -gt 365) {
    $lines += ''
    $lines += "WARNING: this BIOS is $biosAgeDays days old."
}
$lines += @(
    ''
    'Download from:'
    "  $boardUrl"
)
foreach ($k in $gpuLinks.Keys) { $lines += "  $($gpuLinks[$k])" }
$lines += @('', 'Open these pages in your browser now?')

$message = $lines -join "`r`n"
$title   = 'ACTION REQUIRED - Update your drivers'

# Own dialog instead of [MessageBox]::Show with a hidden owner form. That
# trick did the opposite of what its comment claimed: a MessageBox owned by
# another window does NOT inherit TopMost (WS_EX_TOPMOST stays unset), gets no
# taskbar button and no Alt-Tab entry, and it is placed on the monitor nearest
# its owner - which was parked at (-3000,-3000). So the moment anything took
# focus, or a second display was attached (Parsec / RDP virtual adapters), the
# question sat behind the console with no way to reach it and the installer
# looked frozen on its last printed line.
function Show-DriverDialog {
    param([string]$Text, [string]$Title, [int]$Seconds)

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing        -ErrorAction Stop

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = $Title
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.TopMost         = $true     # real topmost: this form owns nothing
    $form.ShowInTaskbar   = $true     # clickable in taskbar / Alt-Tab if buried
    $form.ClientSize      = New-Object System.Drawing.Size(620, 380)

    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline   = $true
    $box.ReadOnly    = $true
    $box.ScrollBars  = 'Vertical'
    $box.BorderStyle = 'None'
    $box.BackColor   = $form.BackColor
    $box.TabStop     = $false
    $box.Font        = New-Object System.Drawing.Font('Consolas', 9.75)
    $box.Text        = $Text
    $box.SetBounds(12, 12, 596, 290)

    $yes = New-Object System.Windows.Forms.Button
    $yes.Text         = 'Open pages'
    $yes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $yes.SetBounds(396, 320, 104, 30)

    $no = New-Object System.Windows.Forms.Button
    $no.Text         = 'Later'
    $no.DialogResult = [System.Windows.Forms.DialogResult]::No
    $no.SetBounds(508, 320, 100, 30)

    $count = New-Object System.Windows.Forms.Label
    $count.SetBounds(12, 326, 370, 20)
    $count.ForeColor = [System.Drawing.Color]::DimGray

    $form.Controls.AddRange(@($box, $yes, $no, $count))
    $form.AcceptButton = $yes
    $form.CancelButton = $no
    $form.Add_Shown({
        $form.Activate()
        [System.Media.SystemSounds]::Exclamation.Play()
    })

    # An unattended install must never wait for ever: count down, then "Later".
    $timer = $null
    if ($Seconds -gt 0) {
        $state = @{ Left = $Seconds }
        $count.Text = "Continuing without opening in $($state.Left)s"
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            $state.Left--
            if ($state.Left -le 0) {
                $timer.Stop()
                $form.DialogResult = [System.Windows.Forms.DialogResult]::No
                $form.Close()
            } else {
                $count.Text = "Continuing without opening in $($state.Left)s"
            }
        })
        $timer.Start()
    }

    $answer = $form.ShowDialog()
    if ($timer) { $timer.Stop(); $timer.Dispose() }
    $form.Dispose()
    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

$openThem = $OpenBrowser
if (-not $openThem) {
    if (-not [Environment]::UserInteractive) {
        # Scheduled task / service: nobody can answer, so do not ask.
        Write-Host "`n  (non-interactive session - skipping the driver prompt)" -ForegroundColor DarkGray
    } else {
        try {
            $openThem = Show-DriverDialog -Text $message -Title $title -Seconds $TimeoutSeconds
        } catch {
            # Headless / no WinForms (Server Core, SSH session): fall back to console.
            Write-Host "`n$message`n" -ForegroundColor Yellow
            $openThem = ((Read-Host 'Open these pages now? [y/N]') -match '^y')
        }
    }
}

if ($openThem) {
    Start-Process $boardUrl
    foreach ($k in $gpuLinks.Keys) { Start-Process $gpuLinks[$k] }
}
