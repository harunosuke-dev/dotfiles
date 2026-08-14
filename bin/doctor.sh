#!/bin/sh

###########################################################
# Dotfiles Doctor - 設定と実環境のズレを検査する
###########################################################
# Usage: ./bin/doctor.sh
#
# 1. 壊れたシンボリックリンクの検出
# 2. 設定パッケージに対応するコマンドの存在確認
#    （設定だけ残って実体がない「死に設定」を早期発見する）
# 3. Brewfileと実際のインストール状況の差分

# symlink経由（~/.local/bin/doctor.sh）でも実体を解決できるよう readlink -f を使う
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_DIR/scripts/utils.sh"

TOTAL_ISSUES=0

# 1) 壊れたシンボリックリンク
log_step "LINKS" "Checking for broken symlinks..."
broken="$(find -L "$HOME" -maxdepth 1 -type l 2>/dev/null; find -L "$HOME/.config" "$HOME/.ssh" -maxdepth 2 -type l 2>/dev/null)"
if [ -n "$broken" ]; then
    echo "$broken" | while read -r link; do
        log_warn "Broken symlink: $link"
    done
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
else
    log_success "No broken symlinks"
fi

# 2) 設定パッケージ → コマンドの対応
#    packages/ にstow設定があるのに、コマンド本体が入っていないものを警告する
log_step "TOOLS" "Checking package/command pairs..."
pairs="alacritty:alacritty bat:bat fd:fd fzf:fzf gh:gh lazygit:lazygit mise:mise navi:navi ripgrep:rg skhd:skhd starship:starship tmux:tmux vim:vim yabai:yabai hammerspoon:hs"
tool_issues=0
for pair in $pairs; do
    pkg="${pair%%:*}"
    cmd="${pair##*:}"
    if [ -d "$REPO_DIR/packages/$pkg" ] && ! command -v "$cmd" >/dev/null 2>&1; then
        log_warn "packages/$pkg exists but '$cmd' is not installed"
        tool_issues=$((tool_issues + 1))
    fi
done
if [ "$tool_issues" -eq 0 ]; then
    log_success "All configured tools are installed"
else
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

# 3) Brewfileとの差分
log_step "BREW" "Checking Brewfile sync..."
if brew bundle check --file "$REPO_DIR/homebrew/Brewfile" >/dev/null 2>&1; then
    log_success "Brewfile is in sync"
else
    log_warn "Brewfile and installed packages differ:"
    brew bundle check --verbose --file "$REPO_DIR/homebrew/Brewfile" 2>/dev/null | grep -iv "satisfied" | head -10
    log_info "Fix with: brew bundle --file $REPO_DIR/homebrew/Brewfile"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

echo ""
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    log_success "Doctor: no issues found"
else
    log_warn "Doctor: $TOTAL_ISSUES issue group(s) found"
    exit 1
fi
