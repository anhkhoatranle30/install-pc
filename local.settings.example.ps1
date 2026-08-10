<#
    Chép file này thành  local.settings.ps1  rồi điền giá trị thật vào.

        Copy-Item local.settings.example.ps1 local.settings.ps1

    local.settings.ps1 đã nằm trong .gitignore nên KHÔNG bao giờ bị commit.
    File example này thì được commit - đừng điền giá trị thật vào đây.

    install.ps1 tự động dot-source local.settings.ps1 nếu thấy nó.
#>

# ------------------------------------------------------------------
# ZeroTier
# ------------------------------------------------------------------
# Network ID 16 ký tự hex. Để trống thì script bỏ qua bước join.
#
# Network ID không phải là secret theo nghĩa mật khẩu - biết ID vẫn không
# vào được mạng, vì bạn còn phải authorize node đó ở my.zerotier.com.
# Nhưng nó vẫn để lộ hạ tầng nội bộ, nên vẫn để ở đây thay vì commit.
$ZeroTierNetworkId = ''

# ------------------------------------------------------------------
# Beyond Compare 5
# ------------------------------------------------------------------
# CÁCH 1 (an toàn hơn): trỏ ĐƯỜNG DẪN tới file license đã lưu.
# Lấy file: mở Beyond Compare đã activate -> Help -> Enter Key -> Save As...
# Đặt file ngoài repo (USB, OneDrive), ví dụ:
#   $BeyondCompareLicenseFile = "$env:USERPROFILE\OneDrive\keys\BCLicense"
$BeyondCompareLicenseFile = ''

# CÁCH 2: dán thẳng nội dung key vào đây. File này gitignored nên không lên
# git, nhưng nó nằm nguyên văn trên đĩa - đừng chụp màn hình hay share file.
# Dán nguyên khối, kể cả dòng "--- BEGIN LICENSE KEY ---" nếu có.
$BeyondCompareLicenseText = @'
'@

# ------------------------------------------------------------------
# Git
# ------------------------------------------------------------------
$GitUserName  = ''
$GitUserEmail = ''
