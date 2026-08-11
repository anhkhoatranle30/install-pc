# install-pc

Setup script cho PC Windows mới.

## Chạy

Right-click `install.cmd` → **Run as administrator**.

Xong thì **đóng và mở lại Windows Terminal** (và nên reboot 1 lần cho WSL + PATH).

## Cấu trúc

| File | Việc |
|---|---|
| **`config.ps1`** | **Sở thích — font, theme, màu, port. Sửa file này là đủ.** |
| `install.cmd` | Bootstrap: check admin → gọi `install.ps1` bằng `pwsh` nếu có, không thì `powershell` |
| `install.ps1` | Cài toàn bộ phần mềm (winget, fallback chocolatey) |
| `setup-terminal.ps1` | Ghi `$PROFILE`, `settings.json` của Windows Terminal / VS Code, context menu, Clink |
| `setup-wsl.ps1` | Bật Windows feature + cài Ubuntu 22.04 |
| `setup-power-remote.ps1` | Tắt sleep + bật Remote Desktop + firewall |
| `setup-git-diff.ps1` | Beyond Compare làm diff/merge tool cho git + TortoiseGit |
| `setup-quil.ps1` | Cài Quil (terminal multiplexer sống qua reboot) |
| `check-drivers.ps1` | Detect mainboard/BIOS/GPU → popup nhắc update driver |
| `check-font.ps1` | Kiểm tra font có đủ glyph tiếng Việt + powerline không |
| `fix-path.ps1` | Dọn user PATH bị `setx` làm hỏng |
| `local.settings.ps1` | **gitignored** — ZeroTier network ID, đường dẫn license |

Hai file cấu hình, đừng lẫn:

| | `config.ps1` | `local.settings.ps1` |
|---|---|---|
| Chứa | sở thích (font, theme, màu, port) | bí mật (key, network ID) |
| Commit? | **có** | **không** — gitignored |

> Bản cũ nhét lệnh PowerShell (`Install-Module`, `Set-ExecutionPolicy`, `$PROFILE`…) thẳng vào file `.cmd`.
> `cmd.exe` không hiểu nên phần đó **chưa bao giờ chạy** — đó là lý do terminal chưa đẹp và không có intellisense.

## Chạy lại từng phần

```powershell
.\install.ps1 -OnlyTerminal              # chỉ prompt đẹp + intellisense, KHÔNG đụng app khác
.\install.ps1 -SkipApps                  # chỉ config terminal + check driver
.\install.ps1 -SkipWsl                   # bỏ qua WSL (bước cần reboot)
.\install.ps1 -OnlyDrivers               # chỉ popup driver
.\check-drivers.ps1 -NoPopup             # in ra console, không popup
.\setup-terminal.ps1                     # chỉ config lại terminal
.\setup-power-remote.ps1                 # tắt sleep + bật RDP (port 3389)
.\setup-power-remote.ps1 -RdpPort 13389  # đổi port RDP
.\setup-power-remote.ps1 -AllowScreenOff # cho phép tắt màn hình (vẫn không sleep)
```

Tất cả script **chạy lại được nhiều lần**. File config cũ được backup thành `*.bak-<timestamp>`,
và phần do script sinh ra nằm giữa 2 marker `# ===== BEGIN/END install-pc =====` nên đồ tự thêm
ở ngoài block đó không bị mất.

## Không còn phải paste tay

Trước đây script mở `notepad $PROFILE` rồi bắt tự copy nội dung vào. Giờ `setup-terminal.ps1`
ghi thẳng:

- **`$PROFILE`** (cả PowerShell 7 và Windows PowerShell 5.1) — oh-my-posh, Terminal-Icons,
  posh-git, PSReadLine predictive intellisense, argument completer cho `winget`/`choco`, alias.
- **Windows Terminal `settings.json`** — font Nerd Font, color scheme, acrylic, default profile = PowerShell 7.
- **VS Code `settings.json`** — font + ligatures.
- **Registry** — `Open with Code` cho file / folder / nền folder.

## Intellisense

| Shell | Cách |
|---|---|
| PowerShell 7 / 5.1 | PSReadLine `ListView` — gõ vài ký tự là hiện dropdown gợi ý từ history + module. `→` nhận gợi ý, `F2` đổi kiểu hiển thị, `Tab` menu complete |
| `cmd.exe` | **Clink** (`choco install clink`) — cmd không có intellisense native, Clink nhét readline vào: history search, inline suggestion, Tab completion |

## Danh sách phần mềm

Browsers/basics · Git & diff (Git, LFS, TortoiseGit, WinMerge, KDiff3) · Node.js latest ·
Python 3.13 · JDK/JRE · OpenSSL · curl · PowerShell 7 · **PuTTY (kèm PuTTYgen)** ·
VS Code · **Unity Hub** · **Claude Desktop** · **Claude Code CLI** · Teams/Zoom/Postman/MongoDB ·
Windows Terminal + oh-my-posh + Clink + Nerd Fonts · **WSL Ubuntu 22.04**

Visual Studio đã bỏ — Unity Hub tự cài build tools nó cần.

## Driver warning

Windows Update **không** ship driver chipset / LAN / audio / BIOS của mainboard.
`check-drivers.ps1` đọc `Win32_BaseBoard` + `Win32_BIOS` + `Win32_VideoController`, map hãng
→ trang download, cảnh báo nếu BIOS cũ hơn 365 ngày, rồi popup hỏi có mở trang không.

Popup có taskbar button + Alt-Tab và **tự đóng sau 120 giây** (chọn "Later") để install
không bao giờ treo vì chờ trả lời. `-TimeoutSeconds 0` = chờ mãi, `-NoPopup` = chỉ in console.

Hỗ trợ deep-link: Gigabyte, ASUS, MSI, ASRock, Biostar, Supermicro, Framework, Intel, Acer, và
Dell / HP / Lenovo (dùng luôn service tag lấy từ BIOS serial). Hãng khác → fallback Google search.

## Font tiếng Việt

Nerd Font patched thường **rụng hết Latin Extended**, nên tiếng Việt ra ô vuông. Đã đo từng glyph:

| Font | ô | ư | ạ | ẻ | powerline |
|---|---|---|---|---|---|
| Cascadia Code | ✅ | ✅ | ✅ | ✅ | ❌ |
| CaskaydiaCove NF | ❌ | ❌ | ❌ | ❌ | ✅ |
| FiraCode NF | ✅ | ❌ | ❌ | ❌ | ✅ |
| **JetBrainsMono NF** | ✅ | ✅ | ✅ | ✅ | ✅ |

→ dùng `JetBrainsMono NF`, kèm fallback chain `"JetBrainsMono NF, Cascadia Code, Consolas"`
(Windows Terminal 1.20+). `$PROFILE` cũng set UTF-8 cho console.

## Đổi theme / font

**Sửa `config.ps1`, rồi chạy `.\setup-terminal.ps1`.** Hết. Không cần đụng script nào khác.

```powershell
$Cfg = @{
    TerminalFont     = 'JetBrainsMono NF'
    TerminalFontSize = 11
    FontFallback     = 'Cascadia Code, Consolas'
    PoshTheme        = 'jandedobbeleer'
    ColorScheme      = 'One Half Dark'
    Opacity          = 92
    ...
}
```

`config.ps1` điều khiển luôn cả port RDP, distro WSL, thư mục cài Quil — mỗi script
đọc từ đó, và tham số dòng lệnh (nếu truyền) sẽ ghi đè để thử tạm:

```powershell
.\setup-terminal.ps1 -PoshTheme atomic      # thử 1 lần, không sửa config
.\setup-power-remote.ps1 -RdpPort 13389
```

Đổi font xong nhớ kiểm tra glyph tiếng Việt:

```powershell
.\check-font.ps1                  # font đang dùng + các font quen thuộc
.\check-font.ps1 -All             # mọi font trên máy
.\check-font.ps1 -Name 'Hack NF'
```

Xem 122 theme có sẵn:

```powershell
Get-ChildItem $env:POSH_THEMES_PATH -Filter *.omp.json | ForEach-Object { $_.BaseName }
```

Xem trước hình: <https://ohmyposh.dev/docs/themes>. Đổi tạm để thử trong phiên hiện tại:

```powershell
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\atomic.omp.json" | Invoke-Expression
```

Ưng rồi thì ghi vào `config.ps1` cho vĩnh viễn.

> Sửa font/màu bằng GUI của Windows Terminal cũng được, **nhưng** lần chạy
> `setup-terminal.ps1` tiếp theo sẽ ghi đè lại từ `config.ps1`. Muốn giữ lâu dài
> thì sửa trong `config.ps1`.

## Secrets

Key và network ID **không bao giờ commit**. Chép template rồi điền:

```powershell
Copy-Item local.settings.example.ps1 local.settings.ps1
```

`local.settings.ps1` nằm trong `.gitignore`. `install.ps1` tự dot-source nếu thấy.
Với Beyond Compare, biến trỏ **đường dẫn tới file license**, không phải nội dung key —
để file đó ngoài repo (OneDrive/USB).

## Encoding

File `.ps1` có tiếng Việt **phải lưu UTF-8 kèm BOM**. Windows PowerShell 5.1 đọc `.ps1`
theo ANSI, không BOM thì chữ có dấu vỡ thành byte rác và **script không parse được**.
Máy mới chưa có pwsh 7 sẽ dính đúng lỗi này. Kiểm tra:

```powershell
powershell.exe -NoProfile -Command "Get-ChildItem *.ps1 | ForEach-Object { `$e=`$null; [void][System.Management.Automation.Language.Parser]::ParseFile(`$_.FullName,[ref]`$null,[ref]`$e); if(`$e){ `"FAIL `$(`$_.Name)`" } }"
```

## "oh-my-posh is not recognized" (và winget, pwsh...)

File có thật trên đĩa mà lệnh vẫn báo không tìm thấy → **user PATH bị hỏng**.

Thủ phạm là `setx PATH "%PATH%;..."`. `%PATH%` là PATH **đã gộp** system+user, nên
setx chép nguyên system PATH vào user PATH rồi **cắt cụt ở 1024 ký tự** — thường nuốt
mất `%LOCALAPPDATA%\Microsoft\WindowsApps`, nơi Windows để app execution alias của
winget / pwsh / oh-my-posh.

```powershell
.\fix-path.ps1           # xem trước, không ghi gì
.\fix-path.ps1 -Apply    # ghi thật, có backup
.\fix-path.ps1 -Restore "C:\...\userpath-<timestamp>.txt"
```

Bỏ mục nào user PATH có mà system PATH cũng có (không mất gì), bỏ mục lặp, bỏ mục
trỏ tới thư mục không tồn tại, và bảo đảm có WindowsApps.

Đừng bao giờ dùng `setx` để thêm PATH. Dùng:

```powershell
$p = [Environment]::GetEnvironmentVariable('Path','User')
[Environment]::SetEnvironmentVariable('Path', "$p;C:\thu\muc\moi", 'User')
```

## Cascadia Code ≠ CaskaydiaCove

Hai font khác nhau, tên gần giống. Nerd Fonts đổi "Cascadia" → "Caskaydia" khi patch
để tránh trademark:

| | tổng glyph | Latin Extended (U+0100–U+1EFF) | powerline |
|---|---|---|---|
| **Cascadia Code** (Microsoft gốc) | 1483 | **563** | ❌ |
| **CaskaydiaCove NF** (Nerd Fonts patch) | 3804 | **0** | ✅ |

Bản patched nhiều glyph hơn vì thêm cả nghìn icon, nhưng **rụng sạch** Latin Extended —
nơi chứa `ư ạ ẻ`. Nên "Cascadia Code hiển thị tiếng Việt tốt" là đúng, mà
"CaskaydiaCove không có tiếng Việt" cũng đúng.

Trong repo này: terminal dùng JetBrainsMono NF (có cả hai), editor dùng Cascadia Code
(editor không cần powerline).

## Power & Remote Desktop

`setup-power-remote.ps1` tắt sleep/hibernate/disk-spindown, **kể cả "unattended sleep"** — timer ẩn
không có trong Settings UI, là thủ phạm khiến máy ngủ vài phút sau khi ngắt RDP. Cũng tắt luôn
power-saving của NIC qua registry `PnPCapabilities=24` (cmdlet `Set-NetAdapterPowerManagement` lỗi
trên nhiều driver).

RDP bật kèm **NLA bắt buộc**, firewall chỉ mở **Domain + Private**. Đừng port-forward 3389 ra
internet — connect qua IP ZeroTier.
