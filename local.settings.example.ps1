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
# ĐƯỜNG DẪN tới file license đã lưu, KHÔNG phải nội dung key.
# Lấy file này bằng cách: mở Beyond Compare đã activate ->
#   Help -> Enter Key -> Save As...  (hoặc copy sẵn từ máy cũ)
#
# Đặt file ở ngoài repo (USB, OneDrive, thư mục riêng), ví dụ:
#   $BeyondCompareLicenseFile = "$env:USERPROFILE\OneDrive\keys\BCLicense"
#
# Đừng paste nội dung key thẳng vào biến - file này tuy gitignored nhưng
# trỏ đường dẫn vẫn an toàn hơn là nhúng key vào script.
$BeyondCompareLicenseFile = ''

# ------------------------------------------------------------------
# Git
# ------------------------------------------------------------------
$GitUserName  = ''
$GitUserEmail = ''
