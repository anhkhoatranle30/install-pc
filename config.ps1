<#
    ============================================================
      SỞ THÍCH - sửa file này, không cần đụng script nào khác.
    ============================================================

    Đây là file DUY NHẤT bạn cần sửa khi muốn đổi font, theme, màu, port...
    Mọi script khác đều đọc từ đây.

    Sửa xong thì chạy lại script tương ứng để áp dụng:
        .\setup-terminal.ps1        font, theme, màu terminal + VS Code
        .\setup-power-remote.ps1    port RDP
        .\setup-quil.ps1 -Force     thư mục cài Quil

    File này ĐƯỢC commit (nó là sở thích, không phải bí mật).
    Key và network ID thì để ở local.settings.ps1 - file đó gitignored.
#>

$Cfg = @{

    # ---------------------------------------------------------------
    #  FONT
    # ---------------------------------------------------------------
    # CẢNH BÁO: phần lớn Nerd Font patched bị rụng glyph tiếng Việt.
    # Đổi font xong nhớ kiểm tra bằng:  .\check-font.ps1
    #
    # Đã đo sẵn:  JetBrainsMono NF  -> đủ tiếng Việt + powerline  ✔
    #             CaskaydiaCove NF  -> KHÔNG có ký tự tiếng Việt nào
    #             FiraCode NF       -> chỉ có 'ô', thiếu 'ư' 'ạ' 'ẻ'
    TerminalFont   = 'JetBrainsMono NF'
    TerminalFontSize = 11

    # Font dự phòng cho glyph mà font chính không có (Windows Terminal 1.20+).
    # Cứ để Cascadia Code - nó có đủ tiếng Việt.
    FontFallback   = 'Cascadia Code, Consolas'

    EditorFont     = 'JetBrainsMono NF'
    EditorFontSize = 14

    # Package sẽ cài để có mấy font trên. Đổi font ở trên thì thêm package
    # tương ứng vào đây, nếu không font sẽ không tồn tại trên máy.
    #   @{ Name = 'tên hiển thị'; Winget = 'id' hoặc Choco = 'id' }
    FontPackages   = @(
        @{ Name = 'JetBrainsMono Nerd Font'; Winget = 'DEVCOM.JetBrainsMonoNerdFont' }
        @{ Name = 'CaskaydiaCove Nerd Font'; Choco  = 'cascadia-code-nerd-font' }
        @{ Name = 'FiraCode Nerd Font';      Choco  = 'firacodenf' }
    )

    # ---------------------------------------------------------------
    #  PROMPT (oh-my-posh)
    # ---------------------------------------------------------------
    # Xem 122 theme có sẵn:
    #     Get-ChildItem $env:POSH_THEMES_PATH -Filter *.omp.json | % { $_.BaseName }
    # Xem hình trước: https://ohmyposh.dev/docs/themes
    # Thử nhanh không cần sửa file:
    #     oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\atomic.omp.json" | Invoke-Expression
    PoshTheme      = 'jandedobbeleer'

    # ---------------------------------------------------------------
    #  MÀU & GIAO DIỆN TERMINAL
    # ---------------------------------------------------------------
    # Scheme có sẵn: Campbell, Campbell Powershell, Vintage, One Half Dark,
    # One Half Light, Solarized Dark, Solarized Light, Tango Dark, Tango Light
    ColorScheme    = 'One Half Dark'
    UseAcrylic     = $true
    Opacity        = 92          # 0-100, càng nhỏ càng trong
    Padding        = '10'
    CursorShape    = 'filledBox' # bar | vintage | underscore | filledBox | emptyBox
    ScrollbarState = 'hidden'    # visible | hidden
    CopyOnSelect   = $true

    # Đặt PowerShell 7 làm profile mặc định của Windows Terminal
    DefaultToPwsh  = $true

    # ---------------------------------------------------------------
    #  VS CODE
    # ---------------------------------------------------------------
    # Script chỉ THÊM key còn thiếu, không bao giờ đè key bạn đã tự đặt.
    VsCodeLigatures = $true

    # ---------------------------------------------------------------
    #  REMOTE DESKTOP
    # ---------------------------------------------------------------
    RdpPort        = 3389
    # $false = màn hình cũng không tắt. $true = cho tắt màn hình (máy vẫn thức).
    AllowScreenOff = $false

    # ---------------------------------------------------------------
    #  KHÁC
    # ---------------------------------------------------------------
    WslDistro      = 'Ubuntu-22.04'
    QuilInstallDir = "$env:LOCALAPPDATA\Quil"
}

# Cho phép script gọi tới dù được dot-source ở scope nào.
$Global:Cfg = $Cfg
