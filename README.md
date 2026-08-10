# install-pc

Setup script cho PC Windows mới.

## Chạy

Right-click `install.cmd` → **Run as administrator**.

Xong thì **đóng và mở lại Windows Terminal** (và nên reboot 1 lần cho WSL + PATH).

## Cấu trúc

| File | Việc |
|---|---|
| `install.cmd` | Bootstrap: check admin → gọi `install.ps1` bằng `pwsh` nếu có, không thì `powershell` |
| `install.ps1` | Cài toàn bộ phần mềm (winget, fallback chocolatey) |
| `setup-terminal.ps1` | Ghi `$PROFILE`, `settings.json` của Windows Terminal / VS Code, context menu, Clink |
| `setup-wsl.ps1` | Bật Windows feature + cài Ubuntu 22.04 |
| `setup-power-remote.ps1` | Tắt sleep + bật Remote Desktop + firewall |
| `check-drivers.ps1` | Detect mainboard/BIOS/GPU → popup nhắc update driver |

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

## Power & Remote Desktop

`setup-power-remote.ps1` tắt sleep/hibernate/disk-spindown, **kể cả "unattended sleep"** — timer ẩn
không có trong Settings UI, là thủ phạm khiến máy ngủ vài phút sau khi ngắt RDP. Cũng tắt luôn
power-saving của NIC qua registry `PnPCapabilities=24` (cmdlet `Set-NetAdapterPowerManagement` lỗi
trên nhiều driver).

RDP bật kèm **NLA bắt buộc**, firewall chỉ mở **Domain + Private**. Đừng port-forward 3389 ra
internet — connect qua IP ZeroTier.
