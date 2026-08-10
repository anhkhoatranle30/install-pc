#!/usr/bin/env bash
# Cài shell cho WSL sao cho giống bên Windows: prompt oh-my-posh + intellisense.
#
# Bên Linux không có PSReadLine. Tương đương gần nhất:
#   zsh-autosuggestions      -> gợi ý xám inline từ history (mũi tên phải để nhận)
#   zsh-syntax-highlighting  -> lệnh sai đổi màu đỏ ngay khi gõ
#   compinit + menu select   -> Tab completion (mạnh hơn bash nhiều)
#   fzf                      -> Ctrl+R tìm history kiểu fuzzy
#   oh-my-posh               -> đúng prompt như bên Windows
#
# Chạy hai pha, vì pha system cần root còn pha user thì không:
#   sudo bash wsl-setup-shell.sh --system <username>
#   bash wsl-setup-shell.sh --user <posh-theme>
#
# Thường thì bạn không gọi trực tiếp - dùng .\setup-wsl-shell.ps1 bên Windows.
#
# KHÔNG cần cài font trong WSL: Windows Terminal mới là cái render chữ, nó đã
# dùng font đặt trong config.ps1 rồi.

set -euo pipefail

BEGIN_MARK='# ===== BEGIN install-pc ====='
END_MARK='# ===== END install-pc ====='

ok()   { printf '  \033[32m[ ok ]\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m[warn]\033[0m %s\n' "$1"; }
step() { printf '\n\033[36m=== %s ===\033[0m\n' "$1"; }

# ---------------------------------------------------------------- system
phase_system() {
    local user="${1:-}"
    step 'Cài gói (cần root)'

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq zsh git curl unzip fzf ca-certificates >/dev/null
    ok 'zsh, git, curl, unzip, fzf'

    if [ -n "$user" ]; then
        # chsh bình thường hỏi mật khẩu; chạy dưới root thì không.
        if [ "$(getent passwd "$user" | cut -d: -f7)" != "$(command -v zsh)" ]; then
            chsh -s "$(command -v zsh)" "$user"
            ok "login shell của $user -> zsh (có hiệu lực ở phiên WSL mới)"
        else
            ok "login shell của $user đã là zsh"
        fi
    fi
}

# ---------------------------------------------------------------- user
phase_user() {
    local theme="${1:-robbyrussell}"

    step 'oh-my-posh'
    mkdir -p "$HOME/.local/bin"
    if ! command -v oh-my-posh >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/oh-my-posh" ]; then
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" >/dev/null
    fi
    export PATH="$HOME/.local/bin:$PATH"
    if command -v oh-my-posh >/dev/null 2>&1; then
        ok "oh-my-posh $(oh-my-posh version 2>/dev/null || echo '?')"
    else
        warn 'oh-my-posh chưa cài được - prompt sẽ dùng mặc định của zsh'
    fi

    # Theme: installer để ở ~/.cache/oh-my-posh/themes. Không có thì tải riêng
    # đúng một file thay vì kéo cả bộ.
    local themes="$HOME/.cache/oh-my-posh/themes"
    mkdir -p "$themes"
    if [ ! -f "$themes/$theme.omp.json" ]; then
        curl -fsSL -o "$themes/$theme.omp.json" \
            "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$theme.omp.json" \
            || warn "không tải được theme '$theme'"
    fi
    [ -f "$themes/$theme.omp.json" ] && ok "theme $theme"

    step 'Plugin intellisense'
    mkdir -p "$HOME/.zsh"
    clone_or_pull() {
        local url="$1" dir="$2"
        if [ -d "$dir/.git" ]; then
            git -C "$dir" pull --quiet --ff-only 2>/dev/null || true
        else
            git clone --depth 1 --quiet "$url" "$dir"
        fi
        ok "$(basename "$dir")"
    }
    clone_or_pull https://github.com/zsh-users/zsh-autosuggestions \
                  "$HOME/.zsh/zsh-autosuggestions"
    clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting \
                  "$HOME/.zsh/zsh-syntax-highlighting"

    step '~/.zshrc'
    local rc="$HOME/.zshrc"
    [ -f "$rc" ] || : > "$rc"
    cp "$rc" "$rc.bak-$(date +%Y%m%d-%H%M%S)"

    local block
    block=$(cat <<ZSHRC
$BEGIN_MARK
# Sinh bởi install-pc / wsl-setup-shell.sh. Sửa ở NGOÀI hai marker này,
# phần bên trong sẽ bị ghi đè ở lần chạy sau.

export PATH="\$HOME/.local/bin:\$PATH"

# --- History -----------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# --- Completion --------------------------------------------------------
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # không phân biệt hoa thường

# --- Intellisense: gợi ý xám inline từ history -------------------------
# Đây là thứ tương đương PSReadLine bên Windows.
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
fi

# --- Phím: Up/Down lọc history theo tiền tố (giống PSReadLine) ---------
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search      # Up
bindkey '^[[B' down-line-or-beginning-search    # Down
bindkey '^[[1;5C' forward-word                  # Ctrl+Right: nhận 1 từ của gợi ý
bindkey '^[[3~'   delete-char

# --- fzf: Ctrl+R tìm history kiểu fuzzy --------------------------------
# KHÔNG dùng dấu \\ xuống dòng ở đây: khối này sinh ra từ heredoc, backslash
# cuối dòng bị nuốt mất dòng mới và nối hai dòng thành một lệnh hỏng.
for f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh; do
    [ -f "\$f" ] && source "\$f" && break
done

# --- Alias -------------------------------------------------------------
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# --- Prompt ------------------------------------------------------------
export POSH_THEMES_PATH="\$HOME/.cache/oh-my-posh/themes"
if command -v oh-my-posh >/dev/null 2>&1; then
    if [ -f "\$POSH_THEMES_PATH/$theme.omp.json" ]; then
        eval "\$(oh-my-posh init zsh --config \$POSH_THEMES_PATH/$theme.omp.json)"
    else
        eval "\$(oh-my-posh init zsh)"
    fi
fi

# --- Syntax highlighting PHẢI nạp CUỐI CÙNG ----------------------------
# Nó bọc lại các widget của zsh; nạp trước plugin khác sẽ mất highlight.
# Viết trên MỘT dòng - xem ghi chú về backslash ở khối fzf bên trên.
[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
$END_MARK
ZSHRC
)

    # Xoá block cũ (nếu có) rồi ghi lại ở CUỐI file. Dùng sed thuần thay vì
    # python3 - bớt một phụ thuộc, và khớp bằng chuỗi ngắn không có ký tự
    # đặc biệt nên không phải escape gì.
    #
    # Ghi ở cuối là cố ý: zsh-syntax-highlighting bắt buộc phải nạp sau cùng,
    # nên phần tự thêm của bạn nằm trước block này là đúng thứ tự.
    sed -i '/BEGIN install-pc/,/END install-pc/d' "$rc"
    # bỏ dòng trống thừa ở cuối để chạy nhiều lần không làm file phình
    printf '%s\n' "$(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc")" > "$rc.tmp"
    mv "$rc.tmp" "$rc"
    printf '\n%s\n' "$block" >> "$rc"
    ok "$rc"
}

# ---------------------------------------------------------------- check
# Để trong file này chứ không viết bash inline bên PowerShell: chuỗi lệnh đi
# qua PowerShell -> wsl.exe -> bash bị mất biến vòng lặp ($c thành rỗng).
phase_check() {
    printf 'shell=%s\n' "$(getent passwd "$USER" | cut -d: -f7)"
    for c in zsh fzf oh-my-posh git curl; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '%-12s %s\n' "$c" "$(command -v "$c")"
        else
            printf '%-12s %s\n' "$c" '-- chưa có --'
        fi
    done
    for p in "$HOME/.zsh/zsh-autosuggestions" "$HOME/.zsh/zsh-syntax-highlighting"; do
        if [ -d "$p" ]; then printf '%-12s %s\n' "$(basename "$p")" 'đã cài'
        else printf '%-12s %s\n' "$(basename "$p")" '-- chưa có --'; fi
    done
    if grep -q 'BEGIN install-pc' "$HOME/.zshrc" 2>/dev/null; then
        printf '%-12s %s\n' '.zshrc' 'đã cấu hình'
    else
        printf '%-12s %s\n' '.zshrc' '-- chưa cấu hình --'
    fi
}

case "${1:-}" in
    --system) phase_system "${2:-}" ;;
    --user)   phase_user   "${2:-robbyrussell}" ;;
    --check)  phase_check ;;
    *) echo "dùng: $0 --system <user> | --user <theme> | --check" >&2; exit 2 ;;
esac
