# Hướng dẫn cho Claude khi làm việc trong repo này

Repo là bộ script setup PC Windows mới. Dưới đây là những bẫy **đã gặp thật** và
đã tốn thời gian sửa — đọc trước khi sửa code.

## PATH: KHÔNG BAO GIỜ dùng `setx`

```powershell
setx PATH "$env:PATH;C:\thu\muc"        # ❌ PHÁ PATH
```

`$env:PATH` / `%PATH%` là PATH **đã gộp** system+user. `setx` sẽ:
1. chép toàn bộ **system** PATH vào **user** PATH, và
2. **cắt cụt ở 1024 ký tự**.

Máy này đã mất `%LOCALAPPDATA%\Microsoft\WindowsApps` (làm `winget`/`pwsh`/`oh-my-posh`
báo "not recognized") và `%USERPROFILE%\.local\bin` (làm `claude` không chạy) vì đúng lỗi này.

Cách đúng:

```powershell
$cur = [Environment]::GetEnvironmentVariable('Path','User')   # CHỈ user, không gộp
[Environment]::SetEnvironmentVariable('Path', "$cur;C:\thu\muc", 'User')
```

Đã hỏng rồi thì chạy `.\fix-path.ps1` (mặc định chỉ xem trước, `-Apply` mới ghi).
`$PROFILE` có sẵn `Add-UserPath` và một hàm chặn `setx PATH`.

## File `.ps1` có tiếng Việt PHẢI có UTF-8 BOM

Windows PowerShell 5.1 đọc `.ps1` theo ANSI. Không BOM thì chữ có dấu vỡ thành byte
rác và **script không parse được**. Máy mới chưa có pwsh 7 sẽ dính đúng lỗi này.

Sau khi sửa file, luôn kiểm tra trên **cả hai** host:

```powershell
powershell.exe -NoProfile -Command "Get-ChildItem *.ps1 | ForEach-Object { `$e=`$null; [void][System.Management.Automation.Language.Parser]::ParseFile(`$_.FullName,[ref]`$null,[ref]`$e); if(`$e){ `"FAIL `$(`$_.Name)`" } }"
```

Chỉ check bằng pwsh 7 là **không đủ** — pwsh mặc định UTF-8 nên nó không bắt được lỗi.

## Biến PowerShell không phân biệt hoa thường

`$cfg` và `$Cfg` là **cùng một biến**. Đã từng gán JSON đã parse vào `$cfg`, đè mất
`$Cfg` (config), khiến `colorScheme`/`opacity` bị ghi `null` vào settings.json.
Đặt tên rõ ràng: `$wtJson`, `$codeJson`, không dùng `$cfg`.

## Backtick trong here-string sinh `$PROFILE`

`setup-terminal.ps1` sinh `$PROFILE` bằng here-string `@"..."@`. Trong đó `` `r `` là
**escape của carriage return**. Viết `` `reload-path` `` trong comment sẽ cắt đôi dòng
và phần đuôi thành lệnh. **Không dùng backtick trong comment** ở khối đó.

## Sinh file bằng heredoc: KHÔNG dùng `\` xuống dòng

`wsl-setup-shell.sh` sinh `~/.zshrc` bằng heredoc `<<ZSHRC`. Trong đó dấu `\`
cuối dòng **nuốt mất dòng mới**, nối hai dòng thành một:

```sh
[ -f x ] && \        →   [ -f x ] && \    source y    # zsh: command not found
    source y
```

Viết mọi lệnh trên **một dòng** trong khối heredoc. Cùng họ với bẫy backtick ở
`$PROFILE` bên trên.

## `wsl --` nuốt backslash và có hai kiểu encoding

**Backslash:** `wsl -- lệnh "C:\duong\dan"` làm đối số tới nơi thành
`C:duongdan`. Đừng truyền đường dẫn Windows qua `wsl --`; đẩy nội dung qua
**stdin** thay vì qua đường dẫn:

```powershell
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$text | & wsl -d $Distro -- sh -c 'tr -d "\r" > /tmp/script.sh'
```

**Encoding — hai loại khác nhau:**

| Lệnh | Encoding |
|---|---|
| `wsl --list`, `--version` (thông báo của chính wsl.exe) | UTF-16LE |
| `wsl -- <lệnh linux>` (stdout của lệnh Linux) | UTF-8 |

Áp nhầm UTF-16 cho loại thứ hai thì chuỗi ra **chữ Hán**; áp nhầm UTF-8 cho
loại thứ nhất thì có **NUL xen giữa** và mọi `-match` đều trượt.

**File `.sh` phải là LF.** CRLF làm bash báo `bad interpreter: /bin/bash^M`.
`.gitattributes` đã ép `*.sh text eol=lf`.

## Bash inline nhiều lớp quoting thì mất biến

Chuỗi lệnh đi qua PowerShell → `wsl.exe` → bash bị mất biến vòng lặp (`$c`
thành rỗng). Đưa logic vào file `.sh` rồi gọi file đó, đừng viết bash inline
trong PowerShell.

## Registry: `HKCR:\*` là wildcard

Key "mọi loại file" tên đúng là `*`. `New-Item -Path 'HKCR:\*\shell\...'` làm provider
hiểu là wildcard rồi quét cả hive — **treo vài phút và không tạo gì**. Dùng .NET:

```powershell
[Microsoft.Win32.Registry]::ClassesRoot.CreateSubKey('*\shell\VSCode')
```

## Đừng gọi binary TUI để dò version

`quil.exe --version` **treo vô hạn** khi output bị redirect — nó mở TUI thay vì in
version rồi thoát. Dò bằng `Test-Path` trên file, lấy version từ tag release.

## Font: Nerd Font patched thường rụng tiếng Việt

`Cascadia Code` (Microsoft, 563 ký tự Latin Extended) và `CaskaydiaCove NF`
(Nerd Fonts patch, **0** ký tự Latin Extended) là **hai font khác nhau**.
Đổi font xong luôn chạy `.\check-font.ps1`. Dùng fallback chain
(`"FontChinh, Cascadia Code, Consolas"`) để font phụ gánh glyph còn thiếu.

## Hai file cấu hình

| | commit? | chứa gì |
|---|---|---|
| `config.ps1` | ✅ | sở thích: font, theme, màu, port |
| `local.settings.ps1` | ❌ gitignored | bí mật: ZeroTier network ID, đường dẫn license |

Không bao giờ nhúng key/token vào script. `local.settings.ps1` trỏ **đường dẫn** tới
file license, không chứa nội dung key.

## Ghi đè file config của người dùng

`setup-terminal.ps1` từng xoá sạch `settings.json` của VS Code (4384 → 442 bytes) vì
`ConvertFrom-Json` chết ở trailing comma rồi code ghi object rỗng đè lên. Quy tắc:

- Parse lỗi → **abort**, không ghi gì.
- File người dùng đã có → chỉ **thêm** key thiếu, không đè key sẵn có.
- Luôn backup `*.bak-<timestamp>` trước khi ghi.
- `ConvertTo-Json` phá hết comment — settings.json của VS Code có comment, đừng
  reserialize, hãy chèn text.

## Biến môi trường chỉ áp cho tiến trình MỚI

Sửa PATH xong, shell đang mở vẫn giữ giá trị cũ. Trong script, đọc thẳng registry:

```powershell
$env:PATH = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User')
```

Riêng **quil**: pane do daemon `quild` sinh ra nên chúng thừa kế môi trường của
daemon lúc daemon khởi động. Mở tab mới không đủ — phải `quil restart`.

## MessageBox có owner: không TopMost, không taskbar, không Alt-Tab

`check-drivers.ps1` từng tạo một Form ẩn ở `(-3000,-3000)` rồi
`[MessageBox]::Show($owner, ...)` với comment "để ép dialog TopMost". Sai hoàn toàn —
đo bằng `GetWindowLong(GWL_EXSTYLE)` thì `WS_EX_TOPMOST` **không** được set. Tệ hơn:

- Cửa sổ **có owner** thì không có taskbar button và **không xuất hiện trong Alt-Tab**.
- Dialog được đặt giữa **owner**, tức là màn hình gần `(-3000,-3000)` nhất — máy có
  Parsec / RDP virtual display adapter thì nó nhảy sang màn hình khác.

Kết quả: `install.ps1` đứng im ở dòng log cuối, không thấy popup đâu, không click được.
Ai cũng tưởng script treo. Đúng thật là nó đang chờ trả lời một dialog vô hình.

Cách đúng: tự dựng `Form` (không owner) với `TopMost = $true`,
`ShowInTaskbar = $true`, `StartPosition = 'CenterScreen'`, `Add_Shown{ $form.Activate() }`.

## Popup trong script install phải có timeout

Bất kỳ chỗ nào block chờ người dùng (`ShowDialog`, `Read-Host`) đều biến install thành
treo vĩnh viễn khi chạy không người trông. Thêm `Timer` đếm ngược rồi tự chọn mặc định,
và bỏ hẳn prompt khi `-not [Environment]::UserInteractive` (scheduled task / service).

Đếm ngược trong `Add_Tick` phải dùng **hashtable** (`$state = @{ Left = $n }`), không dùng
`$n--` — gán trong scriptblock chỉ tạo biến local của scriptblock, số không bao giờ giảm.
