<#
    ============================================================
      PROFILE CHUỘT - FILE NÀY DO SCRIPT SINH RA
    ============================================================

    Sinh bởi .\setup-mouse.ps1 -Export  lúc 2026-09-22 14:42
    trên máy CPU13387.

    Sửa tay cũng được, nhưng cách gọn hơn là chỉnh chuột trong
    Settings cho vừa ý rồi chạy lại -Export - nó ghi đè file này.

    File ĐƯỢC commit: đây là sở thích, không phải bí mật.
#>

# Đặt tên $MouseProfile chứ không phải $cfg/$Cfg: biến PowerShell không
# phân biệt hoa thường, $cfg đã một lần đè mất config của setup-terminal.
$MouseProfile = @{

    # ---------------------------------------------------------------
    #  TỐC ĐỘ CON TRỎ
    # ---------------------------------------------------------------
    Pointer = @{
        # Thanh trượt trong Mouse Properties: 1..20, mặc định Windows là 10.
        Speed            = 8

        # "Enhance pointer precision" - tăng tốc theo tốc độ vẩy tay.
        EnhancePrecision = $true
        Threshold1       = 6
        Threshold2       = 10

        # Đường cong tăng tốc. SystemParametersInfo không đụng tới hai
        # cái này nên phải ghi thẳng registry, và chỉ ăn sau khi đăng
        # nhập lại. Giá trị dưới đây thường là mặc định của Windows.
        XCurve = @(
            0, 0, 0, 0, 0, 0, 0, 0,
            21, 110, 0, 0, 0, 0, 0, 0,
            0, 64, 1, 0, 0, 0, 0, 0,
            41, 220, 3, 0, 0, 0, 0, 0,
            0, 0, 40, 0, 0, 0, 0, 0
        )
        YCurve = @(
            0, 0, 0, 0, 0, 0, 0, 0,
            253, 17, 1, 0, 0, 0, 0, 0,
            0, 36, 4, 0, 0, 0, 0, 0,
            0, 252, 18, 0, 0, 0, 0, 0,
            0, 192, 187, 1, 0, 0, 0, 0
        )
    }

    # ---------------------------------------------------------------
    #  NÚT BẤM
    # ---------------------------------------------------------------
    Buttons = @{
        SwapButtons       = $false   # đảo nút trái/phải
        DoubleClickSpeed  = 500    # ms; nhỏ = phải bấm nhanh hơn
        DoubleClickWidth  = 4      # px, vùng cho phép lệch
        DoubleClickHeight = 4
        SnapToDefault     = $false   # tự nhảy tới nút mặc định của hộp thoại
        ClickLock         = $false   # giữ nút = khoá kéo thả
        ClickLockTime     = 1200   # chỉ dùng khi ClickLock bật
    }

    # ---------------------------------------------------------------
    #  CUỘN
    # ---------------------------------------------------------------
    Wheel = @{
        ScrollLines    = 3   # số dòng mỗi nấc lăn; -1 = cả trang
        ScrollChars    = 3   # cuộn ngang
        ScrollInactive = $true   # cuộn cửa sổ dưới con trỏ dù không active
    }

    # ---------------------------------------------------------------
    #  HIỂN THỊ CON TRỎ
    # ---------------------------------------------------------------
    Visibility = @{
        Trails            = 0     # 0 = tắt vệt chuột
        HideWhileTyping   = $true   # ẩn con trỏ khi đang gõ
        ShowOnCtrl        = $false  # nhấn Ctrl thì loè vòng tròn quanh con trỏ
        CursorShadow      = $false  # bóng đổ dưới con trỏ
        HoverTime         = 400   # ms trước khi tính là đang hover
        HoverWidth        = 4
        HoverHeight       = 4
        ActiveWndTracking = $false  # rê tới đâu focus tới đó
    }

    # ---------------------------------------------------------------
    #  HÌNH CON TRỎ
    # ---------------------------------------------------------------
    Cursor = @{
        SchemeName   = 'Windows Aero'
        SchemeSource = 2        # 0 = scheme hệ thống, 2 = do người dùng đặt
        BaseSize     = 32       # kích thước gốc, px

        # Nguồn sự thật của trang Settings > Accessibility > Mouse pointer.
        # Phải ghi, không thì Settings tưởng con trỏ vẫn trắng mặc định và
        # lần sau đụng vào là nó sinh đè lại bộ .cur trắng.
        AccessType   = 6        # 0 trắng, 1 đen, 2 đảo màu, 6 màu tuỳ chọn
        AccessColor  = 64250   # 0x00FAFA COLORREF (BGR) = #FAFA00
        AccessSize   = 1        # 1..15, khớp thanh trượt trong Settings

        # Thư mục trong repo chứa .cur cần chép sang
        # %LOCALAPPDATA%\Microsoft\Windows\Cursors của máy mới.
        # Để chuỗi rỗng nếu profile chỉ dùng con trỏ có sẵn của Windows.
        FilesFromRepo = 'cursors'

        # Đường dẫn để nguyên biến môi trường và ghi kiểu REG_EXPAND_SZ.
        # Ghi đường dẫn tuyệt đối C:\Users\<tên>\... như Windows vẫn làm là
        # sang máy khác hỏng ngay, vì username khác.
        Files = [ordered]@{
            Arrow       = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\arrow_eoa.cur'
            Help        = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\helpsel_eoa.cur'
            AppStarting = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\busy_eoa.cur'
            Wait        = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\wait_eoa.cur'
            Crosshair   = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\cross_eoa.cur'
            IBeam       = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\ibeam_eoa.cur'
            NWPen       = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\pen_eoa.cur'
            No          = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\unavail_eoa.cur'
            SizeNS      = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\ns_eoa.cur'
            SizeWE      = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\ew_eoa.cur'
            SizeNWSE    = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\nwse_eoa.cur'
            SizeNESW    = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\nesw_eoa.cur'
            SizeAll     = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\move_eoa.cur'
            UpArrow     = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\up_eoa.cur'
            Hand        = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\link_eoa.cur'
            Pin         = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\pin_eoa.cur'
            Person      = '%LOCALAPPDATA%\Microsoft\Windows\Cursors\person_eoa.cur'
        }
    }
}

$Global:MouseProfile = $MouseProfile
