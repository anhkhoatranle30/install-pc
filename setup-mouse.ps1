<#
    ============================================================
      PROFILE CON CHUỘT - phase riêng, chạy độc lập được
    ============================================================

    Bê nguyên bộ setting chuột + con trỏ từ máy này sang máy mới:
      - tốc độ con trỏ, enhance pointer precision
      - đảo nút, double-click (tốc độ + vùng), snap to default button
      - cuộn: số dòng mỗi nấc, cuộn cửa sổ đang không active
      - ẩn con trỏ khi gõ, vệt chuột, Ctrl để tìm con trỏ
      - HÌNH con trỏ: màu + kích thước

    Toàn bộ là HKCU, KHÔNG cần admin. Nhưng nó ghi vào HKCU của user ĐANG
    chạy script - nếu elevate bằng tài khoản admin khác thì setting rơi vào
    profile của tài khoản đó. Chạy dưới đúng user muốn áp.

    Usage:
        .\setup-mouse.ps1              # áp mouse-profile.ps1 vào máy này
        .\setup-mouse.ps1 -Check       # chỉ in ra khác gì, KHÔNG ghi gì
        .\setup-mouse.ps1 -SkipCursor  # chỉ tốc độ/nút/cuộn, giữ hình con trỏ cũ
        .\setup-mouse.ps1 -Export      # chụp máy HIỆN TẠI -> mouse-profile.ps1 + cursors\

    Chỉnh chuột bằng tay cho vừa ý rồi chạy -Export là profile trong repo
    được cập nhật. Commit. Máy sau chạy install là có y hệt.

    ------------------------------------------------------------
      Vì sao phải kèm thư mục cursors\
    ------------------------------------------------------------
    Khi chọn con trỏ màu tuỳ chọn (Settings > Accessibility > Mouse pointer),
    Windows 11 KHÔNG dùng file trong C:\Windows\Cursors. Nó TỰ SINH 17 file
    *_eoa.cur vào %LOCALAPPDATA%\Microsoft\Windows\Cursors rồi ghi ĐƯỜNG DẪN
    TUYỆT ĐỐI (C:\Users\<tên-bạn>\...) vào registry.

    Hai hệ quả:

      1. Export registry bằng regedit rồi import sang máy khác là HỎNG.
         Username khác nhau, đường dẫn trỏ vào hư không, con trỏ về mặc định
         mà không báo lỗi gì. Script này ghi lại thành
         %LOCALAPPDATA%\... kiểu REG_EXPAND_SZ nên user nào cũng đúng.

      2. File .cur phải đi kèm, nên chúng nằm trong cursors\ của repo
         (17 file, 2.3 MB thô, git nén còn ~56 KB).

    Vẫn ghi cả HKCU\Software\Microsoft\Accessibility (CursorType / CursorColor
    / CursorSize) để trang Settings hiện đúng trạng thái - không thì Settings
    vẫn tưởng con trỏ đang màu trắng mặc định và lần sau người dùng đụng vào
    là Windows sinh đè lại bộ .cur trắng.
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Export,
    [switch]$SkipCursor,
    # Để trống thì lấy mouse-profile.ps1 cạnh script này.
    [string]$ProfileFile
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
if (-not $ProfileFile) { $ProfileFile = Join-Path $root 'mouse-profile.ps1' }
$CursorRepoDir = Join-Path $root 'cursors'

function Write-Step { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Write-Ok   { param($t) Write-Host "  [ ok ] $t" -ForegroundColor Green }
function Write-Warn { param($t) Write-Host "  [warn] $t" -ForegroundColor Yellow }
function Write-Err  { param($t) Write-Host "  [fail] $t" -ForegroundColor Red }
function Write-Info { param($t) Write-Host "         $t" -ForegroundColor DarkGray }

$K_MOUSE   = 'HKCU:\Control Panel\Mouse'
$K_CURSORS = 'HKCU:\Control Panel\Cursors'
$K_DESKTOP = 'HKCU:\Control Panel\Desktop'
$K_ACCESS  = 'HKCU:\Software\Microsoft\Accessibility'

# 17 role con trỏ mà Windows 11 dùng. Thứ tự này cũng là thứ tự ghi ra file
# profile, giữ nguyên cho dễ đọc diff.
$CursorRoles = @(
    'Arrow', 'Help', 'AppStarting', 'Wait', 'Crosshair', 'IBeam', 'NWPen',
    'No', 'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow',
    'Hand', 'Pin', 'Person'
)

# ==================================================================
#  SystemParametersInfo - để setting ăn NGAY, không phải đăng nhập lại
# ==================================================================
if (-not ([Management.Automation.PSTypeName]'NativeMouse.Spi').Type) {
    Add-Type -Namespace NativeMouse -Name Spi -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto, EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfoArray(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);

[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto, EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfoRef(uint uiAction, uint uiParam, ref int pvParam, uint fWinIni);
'@
}

# SPIF_UPDATEINIFILE (ghi vào registry) | SPIF_SENDCHANGE (báo cho mọi cửa sổ)
$SPIF = 0x03

# Từng action nhận giá trị ở uiParam hay pvParam là KHÁC NHAU - đưa nhầm chỗ
# thì hàm vẫn trả về true mà không đổi gì. Cột cuối ghi rõ chỗ đặt giá trị.
$SPI_SETMOUSE              = 0x0004   # pv = int[3] { threshold1, threshold2, accel }
$SPI_SETDOUBLECLKWIDTH     = 0x001D   # ui
$SPI_SETDOUBLECLKHEIGHT    = 0x001E   # ui  (0x001F là SPI_GETICONTITLELOGFONT - đòi con trỏ LOGFONT)
$SPI_SETDOUBLECLICKTIME    = 0x0020   # ui
$SPI_SETMOUSEBUTTONSWAP    = 0x0021   # ui
$SPI_SETCURSORS            = 0x0057   # nạp lại con trỏ; chỉ nhận SPIF_SENDCHANGE
$SPI_SETMOUSETRAILS        = 0x005D   # ui
$SPI_SETSNAPTODEFBUTTON    = 0x0060   # ui
$SPI_SETMOUSEHOVERWIDTH    = 0x0063   # ui
$SPI_SETMOUSEHOVERHEIGHT   = 0x0065   # ui
$SPI_SETMOUSEHOVERTIME     = 0x0067   # ui
$SPI_SETWHEELSCROLLLINES   = 0x0069   # ui
$SPI_SETWHEELSCROLLCHARS   = 0x006D   # ui
$SPI_SETMOUSESPEED         = 0x0071   # pv = chính giá trị, KHÔNG phải con trỏ
$SPI_SETACTIVEWINDOWTRACKING = 0x1001 # pv = bool
$SPI_SETCURSORSHADOW       = 0x101B   # pv = bool
$SPI_SETMOUSESONAR         = 0x101D   # pv = bool
$SPI_SETMOUSECLICKLOCK     = 0x101F   # pv = bool
$SPI_SETMOUSEVANISH        = 0x1021   # pv = bool
$SPI_SETMOUSECLICKLOCKTIME = 0x2009   # pv = ms

# Bốn setting dưới đây nằm chung trong mảng byte UserPreferencesMask cùng với
# cả đống thứ không liên quan (hiệu ứng menu, ClearType...). Tự giải mã bit là
# đoán mò - bảng bit trôi nổi trên mạng lệch nhau. Hỏi thẳng Windows.
$SPI_GETACTIVEWINDOWTRACKING = 0x1000   # pv = bool
$SPI_GETCURSORSHADOW         = 0x101A   # pv = bool
$SPI_GETMOUSESONAR           = 0x101C   # pv = bool
$SPI_GETMOUSECLICKLOCK       = 0x101E   # pv = bool
$SPI_GETMOUSEVANISH          = 0x1020   # pv = bool
$SPI_GETMOUSECLICKLOCKTIME   = 0x2008   # pv = ms

function Get-SpiValue {
    param([int]$Action, [int]$Fallback = 0)
    $out = 0
    if ([NativeMouse.Spi]::SystemParametersInfoRef($Action, 0, [ref]$out, 0)) { return [int]$out }
    $Fallback
}

# ==================================================================
#  Đọc registry
# ==================================================================
function Get-RegValue {
    param([string]$Path, [string]$Name, $Default = $null)
    if (-not (Test-Path $Path)) { return $Default }
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $Default }
    $v = $item.$Name
    if ($null -eq $v) { return $Default }
    # Dấu phẩy là bắt buộc: hàm PowerShell trả về mảng thì mặc định BUNG nó ra
    # pipeline, byte[] thành Object[] và mọi check -is [byte[]] đều trượt.
    , $v
}

# Giá trị con trỏ là REG_EXPAND_SZ. Muốn lấy đúng chuỗi %LOCALAPPDATA%\...
# chưa bung thì phải đi đường .NET; Get-ItemProperty luôn bung sẵn.
function Get-RawCursorPath {
    param([string]$Name)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors')
    if (-not $key) { return '' }
    try {
        $v = $key.GetValue($Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $v) { return '' }
        [string]$v
    } finally { $key.Close() }
}

# Số trong Control Panel\Mouse được Windows lưu kiểu REG_SZ ("8", "500"),
# không phải DWORD. Ép về int để so sánh cho khỏi hụt.
function ConvertTo-IntOrNull {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq '') { return $null }
    try { [int]"$Value" } catch { $null }
}

function Get-MouseState {
    [ordered]@{
        Speed             = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseSensitivity')
        Accel             = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseSpeed')
        Threshold1        = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseThreshold1')
        Threshold2        = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseThreshold2')
        SwapButtons       = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'SwapMouseButtons')
        DoubleClickSpeed  = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'DoubleClickSpeed')
        DoubleClickWidth  = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'DoubleClickWidth')
        DoubleClickHeight = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'DoubleClickHeight')
        SnapToDefault     = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'SnapToDefaultButton')
        Trails            = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseTrails')
        HoverTime         = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseHoverTime')
        HoverWidth        = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseHoverWidth')
        HoverHeight       = ConvertTo-IntOrNull (Get-RegValue $K_MOUSE 'MouseHoverHeight')
        ActiveWndTracking = Get-SpiValue $SPI_GETACTIVEWINDOWTRACKING
        XCurve            = Get-RegValue $K_MOUSE 'SmoothMouseXCurve'
        YCurve            = Get-RegValue $K_MOUSE 'SmoothMouseYCurve'

        ScrollLines       = ConvertTo-IntOrNull (Get-RegValue $K_DESKTOP 'WheelScrollLines')
        ScrollChars       = ConvertTo-IntOrNull (Get-RegValue $K_DESKTOP 'WheelScrollChars')
        ScrollInactive    = ConvertTo-IntOrNull (Get-RegValue $K_DESKTOP 'MouseWheelRouting')

        CursorShadow      = Get-SpiValue $SPI_GETCURSORSHADOW
        Sonar             = Get-SpiValue $SPI_GETMOUSESONAR          # Ctrl để tìm con trỏ
        ClickLock         = Get-SpiValue $SPI_GETMOUSECLICKLOCK
        HideWhileTyping   = Get-SpiValue $SPI_GETMOUSEVANISH
        ClickLockTime     = Get-SpiValue $SPI_GETMOUSECLICKLOCKTIME 1200

        SchemeName        = (Get-Item $K_CURSORS -ErrorAction SilentlyContinue).GetValue('')
        SchemeSource      = ConvertTo-IntOrNull (Get-RegValue $K_CURSORS 'Scheme Source')
        BaseSize          = ConvertTo-IntOrNull (Get-RegValue $K_CURSORS 'CursorBaseSize')
        AccessType        = ConvertTo-IntOrNull (Get-RegValue $K_ACCESS 'CursorType')
        AccessColor       = ConvertTo-IntOrNull (Get-RegValue $K_ACCESS 'CursorColor')
        AccessSize        = ConvertTo-IntOrNull (Get-RegValue $K_ACCESS 'CursorSize')
    }
}

# ==================================================================
#  -Export : chụp máy hiện tại thành mouse-profile.ps1 + cursors\
# ==================================================================
function Export-MouseProfile {
    Write-Step 'Export profile chuột từ máy này'

    $s = Get-MouseState
    $lines = [System.Collections.Generic.List[string]]::new()
    function A { param($t) $lines.Add($t) }

    function Fmt-Bool { param($v) if ($v) { '$true' } else { '$false' } }
    # Giá trị null lọt vào file profile là sinh ra dòng "Speed =" -> file không
    # parse được. Thà rơi về mặc định của Windows còn hơn đẻ ra file hỏng.
    function Fmt-Num {
        param($v, $fallback)
        if ($null -eq $v) { Write-Warn "thiếu giá trị, dùng mặc định $fallback"; return "$fallback" }
        "$v"
    }
    function Fmt-Bytes {
        param($b)
        if ($b -isnot [byte[]] -or $b.Length -eq 0) { return '@()' }
        # 8 byte mỗi dòng cho khớp cấu trúc 5 điểm x 8 byte của đường cong.
        $chunks = for ($i = 0; $i -lt $b.Length; $i += 8) {
            '            ' + (($b[$i..([Math]::Min($i + 7, $b.Length - 1))]) -join ', ')
        }
        "@(`r`n" + ($chunks -join ",`r`n") + "`r`n        )"
    }

    # --- con trỏ: phân loại từng file rồi quyết định có chép vào repo không
    $files    = [ordered]@{}
    $toCopy   = @{}
    $sysRoot  = [Environment]::GetFolderPath('Windows')
    $localApp = $env:LOCALAPPDATA

    foreach ($role in $CursorRoles) {
        $raw = Get-RawCursorPath $role
        if (-not $raw) { continue }                       # role để trống = dùng mặc định
        $full = [Environment]::ExpandEnvironmentVariables($raw)
        $name = Split-Path $full -Leaf

        if ($full -like "$sysRoot\*") {
            # File có sẵn của Windows - máy nào cũng có, không cần chép.
            $files[$role] = '%SystemRoot%\Cursors\' + $name
        } else {
            # File tự sinh hoặc scheme bên thứ ba - phải mang theo.
            $files[$role] = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\' + $name
            if (Test-Path -LiteralPath $full) { $toCopy[$name] = $full }
            else { Write-Warn "$role : không thấy file $full - bỏ role này" ; $files.Remove($role) }
        }
    }

    $needRepoFiles = $toCopy.Count -gt 0
    if ($needRepoFiles) {
        New-Item -ItemType Directory -Path $CursorRepoDir -Force | Out-Null
        # Xoá file cũ trước, tránh để lại .cur của profile đời trước làm repo phình.
        Get-ChildItem $CursorRepoDir -Filter *.cur -ErrorAction SilentlyContinue | Remove-Item -Force
        foreach ($n in $toCopy.Keys) { Copy-Item -LiteralPath $toCopy[$n] -Destination (Join-Path $CursorRepoDir $n) -Force }
        $kb = [Math]::Round((Get-ChildItem $CursorRepoDir -Filter *.cur | Measure-Object Length -Sum).Sum / 1KB)
        Write-Ok "chép $($toCopy.Count) file .cur vào cursors\  ($kb KB)"
    } else {
        Write-Info 'con trỏ dùng file sẵn có của Windows - không cần thư mục cursors\'
    }

    $colorNote = ''
    if ($null -ne $s.AccessColor) {
        # COLORREF là 0x00BBGGRR, ngược với #RRGGBB mà người ta quen đọc.
        $c = [int]$s.AccessColor
        $colorNote = '   # 0x{0:X6} COLORREF (BGR) = #{1:X2}{2:X2}{3:X2}' -f $c, ($c -band 0xFF), (($c -shr 8) -band 0xFF), (($c -shr 16) -band 0xFF)
    }

    A '<#'
    A '    ============================================================'
    A '      PROFILE CHUỘT - FILE NÀY DO SCRIPT SINH RA'
    A '    ============================================================'
    A ''
    A "    Sinh bởi .\setup-mouse.ps1 -Export  lúc $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    A "    trên máy $env:COMPUTERNAME."
    A ''
    A '    Sửa tay cũng được, nhưng cách gọn hơn là chỉnh chuột trong'
    A '    Settings cho vừa ý rồi chạy lại -Export - nó ghi đè file này.'
    A ''
    A '    File ĐƯỢC commit: đây là sở thích, không phải bí mật.'
    A '#>'
    A ''
    A '# Đặt tên $MouseProfile chứ không phải $cfg/$Cfg: biến PowerShell không'
    A '# phân biệt hoa thường, $cfg đã một lần đè mất config của setup-terminal.'
    A '$MouseProfile = @{'
    A ''
    A '    # ---------------------------------------------------------------'
    A '    #  TỐC ĐỘ CON TRỎ'
    A '    # ---------------------------------------------------------------'
    A '    Pointer = @{'
    A "        # Thanh trượt trong Mouse Properties: 1..20, mặc định Windows là 10."
    A "        Speed            = $(Fmt-Num $s.Speed 10)"
    A ''
    A '        # "Enhance pointer precision" - tăng tốc theo tốc độ vẩy tay.'
    A "        EnhancePrecision = $(Fmt-Bool ($s.Accel -ne 0))"
    A "        Threshold1       = $(Fmt-Num $s.Threshold1 6)"
    A "        Threshold2       = $(Fmt-Num $s.Threshold2 10)"
    A ''
    A '        # Đường cong tăng tốc. SystemParametersInfo không đụng tới hai'
    A '        # cái này nên phải ghi thẳng registry, và chỉ ăn sau khi đăng'
    A '        # nhập lại. Giá trị dưới đây thường là mặc định của Windows.'
    A "        XCurve = $(Fmt-Bytes $s.XCurve)"
    A "        YCurve = $(Fmt-Bytes $s.YCurve)"
    A '    }'
    A ''
    A '    # ---------------------------------------------------------------'
    A '    #  NÚT BẤM'
    A '    # ---------------------------------------------------------------'
    A '    Buttons = @{'
    A "        SwapButtons       = $(Fmt-Bool ($s.SwapButtons -ne 0))   # đảo nút trái/phải"
    A "        DoubleClickSpeed  = $(Fmt-Num $s.DoubleClickSpeed 500)    # ms; nhỏ = phải bấm nhanh hơn"
    A "        DoubleClickWidth  = $(Fmt-Num $s.DoubleClickWidth 4)      # px, vùng cho phép lệch"
    A "        DoubleClickHeight = $(Fmt-Num $s.DoubleClickHeight 4)"
    A "        SnapToDefault     = $(Fmt-Bool ($s.SnapToDefault -ne 0))   # tự nhảy tới nút mặc định của hộp thoại"
    A "        ClickLock         = $(Fmt-Bool ($s.ClickLock -ne 0))   # giữ nút = khoá kéo thả"
    A "        ClickLockTime     = $(Fmt-Num $s.ClickLockTime 1200)   # chỉ dùng khi ClickLock bật"
    A '    }'
    A ''
    A '    # ---------------------------------------------------------------'
    A '    #  CUỘN'
    A '    # ---------------------------------------------------------------'
    A '    Wheel = @{'
    A "        ScrollLines    = $(Fmt-Num $s.ScrollLines 3)   # số dòng mỗi nấc lăn; -1 = cả trang"
    A "        ScrollChars    = $(Fmt-Num $s.ScrollChars 3)   # cuộn ngang"
    A "        ScrollInactive = $(Fmt-Bool ($s.ScrollInactive -eq 2))   # cuộn cửa sổ dưới con trỏ dù không active"
    A '    }'
    A ''
    A '    # ---------------------------------------------------------------'
    A '    #  HIỂN THỊ CON TRỎ'
    A '    # ---------------------------------------------------------------'
    A '    Visibility = @{'
    A "        Trails            = $(Fmt-Num $s.Trails 0)     # 0 = tắt vệt chuột"
    A "        HideWhileTyping   = $(Fmt-Bool ($s.HideWhileTyping -ne 0))   # ẩn con trỏ khi đang gõ"
    A "        ShowOnCtrl        = $(Fmt-Bool ($s.Sonar -ne 0))  # nhấn Ctrl thì loè vòng tròn quanh con trỏ"
    A "        CursorShadow      = $(Fmt-Bool ($s.CursorShadow -ne 0))  # bóng đổ dưới con trỏ"
    A "        HoverTime         = $(Fmt-Num $s.HoverTime 400)   # ms trước khi tính là đang hover"
    A "        HoverWidth        = $(Fmt-Num $s.HoverWidth 4)"
    A "        HoverHeight       = $(Fmt-Num $s.HoverHeight 4)"
    A "        ActiveWndTracking = $(Fmt-Bool ($s.ActiveWndTracking -ne 0))  # rê tới đâu focus tới đó"
    A '    }'
    A ''
    A '    # ---------------------------------------------------------------'
    A '    #  HÌNH CON TRỎ'
    A '    # ---------------------------------------------------------------'
    A '    Cursor = @{'
    A "        SchemeName   = '$($s.SchemeName)'"
    A "        SchemeSource = $(Fmt-Num $s.SchemeSource 0)        # 0 = scheme hệ thống, 2 = do người dùng đặt"
    A "        BaseSize     = $(Fmt-Num $s.BaseSize 32)       # kích thước gốc, px"
    A ''
    A '        # Nguồn sự thật của trang Settings > Accessibility > Mouse pointer.'
    A '        # Phải ghi, không thì Settings tưởng con trỏ vẫn trắng mặc định và'
    A '        # lần sau đụng vào là nó sinh đè lại bộ .cur trắng.'
    A "        AccessType   = $(Fmt-Num $s.AccessType 0)        # 0 trắng, 1 đen, 2 đảo màu, 6 màu tuỳ chọn"
    A "        AccessColor  = $(Fmt-Num $s.AccessColor 0)$colorNote"
    A "        AccessSize   = $(Fmt-Num $s.AccessSize 1)        # 1..15, khớp thanh trượt trong Settings"
    A ''
    if ($needRepoFiles) {
        A '        # Thư mục trong repo chứa .cur cần chép sang'
        A '        # %LOCALAPPDATA%\Microsoft\Windows\Cursors của máy mới.'
        A '        # Để chuỗi rỗng nếu profile chỉ dùng con trỏ có sẵn của Windows.'
        A "        FilesFromRepo = 'cursors'"
    } else {
        A '        # Profile này chỉ dùng con trỏ có sẵn của Windows -> không cần chép gì.'
        A "        FilesFromRepo = ''"
    }
    A ''
    A '        # Đường dẫn để nguyên biến môi trường và ghi kiểu REG_EXPAND_SZ.'
    A '        # Ghi đường dẫn tuyệt đối C:\Users\<tên>\... như Windows vẫn làm là'
    A '        # sang máy khác hỏng ngay, vì username khác.'
    A '        Files = [ordered]@{'
    $pad = ($files.Keys | Measure-Object -Property Length -Maximum).Maximum
    foreach ($role in $files.Keys) {
        A ("            {0,-$pad} = '{1}'" -f $role, $files[$role])
    }
    A '        }'
    A '    }'
    A '}'
    A ''
    A '$Global:MouseProfile = $MouseProfile'
    A ''

    $text = ($lines -join "`r`n")
    # UTF-8 CÓ BOM: Windows PowerShell 5.1 đọc .ps1 theo ANSI, không BOM là
    # chữ có dấu vỡ và script không parse nổi.
    [IO.File]::WriteAllText($ProfileFile, $text, [Text.UTF8Encoding]::new($true))
    Write-Ok "ghi $ProfileFile"
    Write-Info 'xem lại rồi commit: git add mouse-profile.ps1 cursors/'
}

if ($Export) { Export-MouseProfile; return }

# ==================================================================
#  Nạp profile
# ==================================================================
Write-Step 'Profile chuột'

if (-not (Test-Path $ProfileFile)) {
    Write-Err "không thấy $ProfileFile"
    Write-Info 'chạy .\setup-mouse.ps1 -Export trên máy đã chỉnh chuột vừa ý để sinh file này'
    return
}
. $ProfileFile
if (-not $MouseProfile) { Write-Err "$ProfileFile không đặt `$MouseProfile"; return }

$P = $MouseProfile
$before = Get-MouseState
if ($Check) { Write-Warn '-Check: chỉ xem, không ghi gì' }

# ==================================================================
#  Backup: đủ để bấm đúp là về y như cũ
# ==================================================================
if (-not $Check) {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak    = Join-Path $root "mouse-backup-$stamp.reg"
    $keys   = @('HKCU\Control Panel\Mouse', 'HKCU\Control Panel\Cursors', 'HKCU\Software\Microsoft\Accessibility')
    $parts  = [System.Collections.Generic.List[string]]::new()
    $ok     = $true
    foreach ($k in $keys) {
        $tmp = Join-Path $env:TEMP ("mb-" + [Guid]::NewGuid().ToString('N') + '.reg')
        & reg.exe export $k $tmp /y *> $null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmp)) { $ok = $false; continue }
        # reg export ra UTF-16LE và mỗi file có dòng "Windows Registry Editor..."
        # riêng; gộp lại thì chỉ giữ dòng đó một lần.
        $body = (Get-Content $tmp -Raw -Encoding Unicode) -replace '^\uFEFF?Windows Registry Editor Version 5\.00\s*', ''
        $parts.Add($body)
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    if ($ok -and $parts.Count) {
        [IO.File]::WriteAllText($bak, "Windows Registry Editor Version 5.00`r`n`r`n" + ($parts -join "`r`n"), [Text.UnicodeEncoding]::new($false, $true))
        Write-Ok "backup: $(Split-Path $bak -Leaf)  (bấm đúp để hoàn tác)"
    } else {
        Write-Warn 'không export được backup registry - vẫn chạy tiếp'
    }
}

$script:Applied = 0
$script:Failed  = 0

function Set-SpiUi {
    param([int]$Action, [int]$Value, [string]$What)
    if ($Check) { return }
    if ([NativeMouse.Spi]::SystemParametersInfo($Action, $Value, [IntPtr]::Zero, $SPIF)) { $script:Applied++ }
    else { $script:Failed++; Write-Warn "$What : SystemParametersInfo lỗi $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)" }
}

function Set-SpiPv {
    param([int]$Action, [int]$Value, [string]$What)
    if ($Check) { return }
    if ([NativeMouse.Spi]::SystemParametersInfo($Action, 0, [IntPtr]$Value, $SPIF)) { $script:Applied++ }
    else { $script:Failed++; Write-Warn "$What : SystemParametersInfo lỗi $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)" }
}

function Show-Change {
    param([string]$What, $Now, $Want)
    $nowS = if ($null -eq $Now) { '(chưa có)' } else { "$Now" }
    if ("$nowS" -eq "$Want") { Write-Host "  [ ok ] $What = $Want" -ForegroundColor DarkGray }
    else { Write-Host "  [ -> ] $What : $nowS -> $Want" -ForegroundColor Yellow }
}

# ==================================================================
Write-Step 'Tốc độ con trỏ'

Show-Change 'Pointer speed (1-20)' $before.Speed $P.Pointer.Speed
Set-SpiPv $SPI_SETMOUSESPEED ([int]$P.Pointer.Speed) 'pointer speed'

$accel = if ($P.Pointer.EnhancePrecision) { 1 } else { 0 }
Show-Change 'Enhance pointer precision' ($before.Accel -ne 0) ([bool]$P.Pointer.EnhancePrecision)
if (-not $Check) {
    # Tắt accel thì threshold phải về 0 hết, để lại 6/10 là Windows vẫn tăng tốc.
    $t1 = if ($accel) { [int]$P.Pointer.Threshold1 } else { 0 }
    $t2 = if ($accel) { [int]$P.Pointer.Threshold2 } else { 0 }
    if ([NativeMouse.Spi]::SystemParametersInfoArray($SPI_SETMOUSE, 0, [int[]]@($t1, $t2, $accel), $SPIF)) { $script:Applied++ }
    else { $script:Failed++; Write-Warn 'SPI_SETMOUSE lỗi' }
}

foreach ($c in @(@{ N = 'SmoothMouseXCurve'; V = $P.Pointer.XCurve }, @{ N = 'SmoothMouseYCurve'; V = $P.Pointer.YCurve })) {
    if (-not $c.V -or $c.V.Count -eq 0) { continue }
    $cur = Get-RegValue $K_MOUSE $c.N
    if ($cur -and (@(Compare-Object $cur ([byte[]]$c.V) -SyncWindow 0).Count -eq 0)) { continue }
    Write-Host "  [ -> ] $($c.N) : khác mặc định -> ghi lại" -ForegroundColor Yellow
    if (-not $Check) { Set-ItemProperty -Path $K_MOUSE -Name $c.N -Value ([byte[]]$c.V) -Type Binary }
}

# ==================================================================
Write-Step 'Nút bấm'

$b = $P.Buttons
Show-Change 'Đảo nút trái/phải' ($before.SwapButtons -ne 0) ([bool]$b.SwapButtons)
Set-SpiUi $SPI_SETMOUSEBUTTONSWAP ([int][bool]$b.SwapButtons) 'swap buttons'

Show-Change 'Double-click speed (ms)' $before.DoubleClickSpeed $b.DoubleClickSpeed
Set-SpiUi $SPI_SETDOUBLECLICKTIME ([int]$b.DoubleClickSpeed) 'double-click time'

Show-Change 'Double-click width (px)' $before.DoubleClickWidth $b.DoubleClickWidth
Set-SpiUi $SPI_SETDOUBLECLKWIDTH ([int]$b.DoubleClickWidth) 'double-click width'

Show-Change 'Double-click height (px)' $before.DoubleClickHeight $b.DoubleClickHeight
Set-SpiUi $SPI_SETDOUBLECLKHEIGHT ([int]$b.DoubleClickHeight) 'double-click height'

Show-Change 'Snap to default button' ($before.SnapToDefault -ne 0) ([bool]$b.SnapToDefault)
Set-SpiUi $SPI_SETSNAPTODEFBUTTON ([int][bool]$b.SnapToDefault) 'snap to default'

Show-Change 'ClickLock' ($before.ClickLock -ne 0) ([bool]$b.ClickLock)
Set-SpiPv $SPI_SETMOUSECLICKLOCK ([int][bool]$b.ClickLock) 'click lock'
if ($b.ClickLock -and $b.ClickLockTime) {
    Set-SpiPv $SPI_SETMOUSECLICKLOCKTIME ([int]$b.ClickLockTime) 'click lock time'
}

# ==================================================================
Write-Step 'Cuộn'

$w = $P.Wheel
Show-Change 'Số dòng mỗi nấc lăn' $before.ScrollLines $w.ScrollLines
Set-SpiUi $SPI_SETWHEELSCROLLLINES ([int]$w.ScrollLines) 'wheel scroll lines'

Show-Change 'Cuộn ngang (ký tự)' $before.ScrollChars $w.ScrollChars
Set-SpiUi $SPI_SETWHEELSCROLLCHARS ([int]$w.ScrollChars) 'wheel scroll chars'

# MouseWheelRouting không có SystemParametersInfo tương ứng - chỉ registry,
# và user32 đọc nó lúc đăng nhập nên đổi xong phải sign out mới ăn.
$routing = if ($w.ScrollInactive) { 2 } else { 0 }
Show-Change 'Cuộn cửa sổ không active' ($before.ScrollInactive -eq 2) ([bool]$w.ScrollInactive)
if (-not $Check -and $before.ScrollInactive -ne $routing) {
    Set-ItemProperty -Path $K_DESKTOP -Name 'MouseWheelRouting' -Value $routing -Type DWord
    Write-Info 'MouseWheelRouting chỉ ăn sau khi đăng xuất/đăng nhập lại'
}

# ==================================================================
Write-Step 'Hiển thị con trỏ'

$v = $P.Visibility
Show-Change 'Vệt chuột (mouse trails)' $before.Trails $v.Trails
Set-SpiUi $SPI_SETMOUSETRAILS ([int]$v.Trails) 'mouse trails'

Show-Change 'Ẩn con trỏ khi gõ' ($before.HideWhileTyping -ne 0) ([bool]$v.HideWhileTyping)
Set-SpiPv $SPI_SETMOUSEVANISH ([int][bool]$v.HideWhileTyping) 'mouse vanish'

Show-Change 'Ctrl để tìm con trỏ' ($before.Sonar -ne 0) ([bool]$v.ShowOnCtrl)
Set-SpiPv $SPI_SETMOUSESONAR ([int][bool]$v.ShowOnCtrl) 'mouse sonar'

Show-Change 'Bóng đổ con trỏ' ($before.CursorShadow -ne 0) ([bool]$v.CursorShadow)
Set-SpiPv $SPI_SETCURSORSHADOW ([int][bool]$v.CursorShadow) 'cursor shadow'

Show-Change 'Hover time (ms)' $before.HoverTime $v.HoverTime
Set-SpiUi $SPI_SETMOUSEHOVERTIME ([int]$v.HoverTime) 'hover time'
Set-SpiUi $SPI_SETMOUSEHOVERWIDTH ([int]$v.HoverWidth) 'hover width'
Set-SpiUi $SPI_SETMOUSEHOVERHEIGHT ([int]$v.HoverHeight) 'hover height'

Show-Change 'Rê chuột là focus theo' ($before.ActiveWndTracking -ne 0) ([bool]$v.ActiveWndTracking)
Set-SpiPv $SPI_SETACTIVEWINDOWTRACKING ([int][bool]$v.ActiveWndTracking) 'active window tracking'

# ==================================================================
Write-Step 'Hình con trỏ'

if ($SkipCursor) {
    Write-Warn '-SkipCursor: giữ nguyên hình con trỏ hiện tại'
} else {
    $cur = $P.Cursor

    # --- chép .cur từ repo sang %LOCALAPPDATA% trước, rồi mới trỏ registry vào
    $destDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
    if ($cur.FilesFromRepo) {
        $srcDir = Join-Path $root $cur.FilesFromRepo
        $src    = @(Get-ChildItem $srcDir -Filter *.cur -ErrorAction SilentlyContinue)
        if (-not $src.Count) {
            Write-Err "không thấy file .cur nào trong $srcDir"
            Write-Info 'profile khai FilesFromRepo nhưng thư mục rỗng - bỏ qua phần hình con trỏ'
            $cur = $null
        } elseif (-not $Check) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            $src | Copy-Item -Destination $destDir -Force
            Write-Ok "chép $($src.Count) file .cur vào $destDir"
        } else {
            Write-Host "  [ -> ] sẽ chép $($src.Count) file .cur vào $destDir" -ForegroundColor Yellow
        }
    }

    if ($cur) {
        # Trỏ registry vào file. Role nào file không tồn tại thì BỎ QUA, không
        # ghi đường dẫn chết - ghi vào là con trỏ đó biến mất, khó lần ra.
        $written = 0
        foreach ($role in $cur.Files.Keys) {
            $raw  = [string]$cur.Files[$role]
            $full = [Environment]::ExpandEnvironmentVariables($raw)
            if (-not (Test-Path -LiteralPath $full)) {
                Write-Warn "$role : không thấy $full - giữ nguyên role này"
                continue
            }
            if (-not $Check) {
                # REG_EXPAND_SZ: giữ nguyên %LOCALAPPDATA% để user nào cũng đúng.
                Set-ItemProperty -Path $K_CURSORS -Name $role -Value $raw -Type ExpandString
            }
            $written++
        }
        Write-Host "  [ -> ] $written/$($cur.Files.Count) role con trỏ" -ForegroundColor Yellow

        Show-Change 'Cursor base size' $before.BaseSize $cur.BaseSize
        Show-Change 'Accessibility CursorType' $before.AccessType $cur.AccessType
        Show-Change 'Accessibility CursorColor' $before.AccessColor $cur.AccessColor
        Show-Change 'Accessibility CursorSize' $before.AccessSize $cur.AccessSize

        if (-not $Check) {
            Set-ItemProperty -Path $K_CURSORS -Name '(default)'     -Value ([string]$cur.SchemeName) -Type String
            Set-ItemProperty -Path $K_CURSORS -Name 'Scheme Source' -Value ([int]$cur.SchemeSource)  -Type DWord
            Set-ItemProperty -Path $K_CURSORS -Name 'CursorBaseSize' -Value ([int]$cur.BaseSize)     -Type DWord

            New-Item -Path $K_ACCESS -Force | Out-Null
            Set-ItemProperty -Path $K_ACCESS -Name 'CursorType'  -Value ([int]$cur.AccessType)  -Type DWord
            Set-ItemProperty -Path $K_ACCESS -Name 'CursorColor' -Value ([int]$cur.AccessColor) -Type DWord
            Set-ItemProperty -Path $K_ACCESS -Name 'CursorSize'  -Value ([int]$cur.AccessSize)  -Type DWord

            # Bắt Windows nạp lại con trỏ ngay, khỏi đăng nhập lại.
            # CHỈ SPIF_SENDCHANGE. Kèm SPIF_UPDATEINIFILE (tức $SPIF = 0x03) là
            # hàm trả về false mà GetLastError vẫn 0 - không có gì để ghi ra
            # file ini nên nó từ chối, và con trỏ im lìm không đổi.
            if ([NativeMouse.Spi]::SystemParametersInfo($SPI_SETCURSORS, 0, [IntPtr]::Zero, 0x02)) {
                Write-Ok 'đã nạp lại con trỏ'
            } else {
                Write-Warn 'nạp lại con trỏ không ăn - đăng xuất/đăng nhập lại là thấy'
            }
        }
    }
}

# ==================================================================
Write-Step 'Xong'

if ($Check) {
    Write-Info 'Chưa ghi gì. Bỏ -Check để áp thật.'
} else {
    Write-Ok "$script:Applied thay đổi đã áp"
    if ($script:Failed) { Write-Warn "$script:Failed thay đổi lỗi" }
    Write-Info 'Cuộn cửa sổ không active và đường cong tăng tốc cần đăng nhập lại mới ăn.'
    Write-Info 'Kiểm tra lại: .\setup-mouse.ps1 -Check'
}
