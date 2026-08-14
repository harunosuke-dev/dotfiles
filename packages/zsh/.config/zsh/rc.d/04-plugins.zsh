# ==========================================
#  Zinit Plugins Configuration
# ==========================================

# ==========================================
#  Shell Enhancement Plugins
# ==========================================

# 補完は zsh 標準の compinit のみ
#
# NOTE: この節は順序が意味を持つ - 並べ替える前に下のコメントを読むこと

# 1. fpath を足すだけのプラグイン。compinit より前に読む
zinit light-mode blockf for \
    atload'async_init' @'mafredri/zsh-async' \
    @'zsh-users/zsh-completions'

# 2. 補完システムの初期化。fpath が出揃った後に呼ぶ
autoload -Uz compinit
compinit -i -d "$_comp_dumpfile"   # -i = 安全でない fpath を黙って飛ばす
zinit cdreplay -q                   # ここまでに queue された compdef を流す

# 3. ウィジェットを包むプラグイン。補完の初期化より後に読んで上から包ませる
zinit light-mode for \
    @'zsh-users/zsh-autosuggestions'
zinit light-mode blockf for \
    @'zdharma-continuum/fast-syntax-highlighting'

# zsh-autopair - Automatically pair brackets and quotes
zinit light-mode for \
    @'hlissner/zsh-autopair'

# ==========================================
#  Package Management Strategy
# ==========================================
#
# Homebrew: System tools, heavy dependencies, frequent updates
# - starship, ripgrep, gh, eza, bat, fd, delta, navi
# - Completions: /opt/homebrew/share/zsh/site-functions/
#
# zinit: Lightweight utilities, shell-specific plugins
# - mmv, zoxide
# - zsh-autosuggestions, fast-syntax-highlighting, etc.
#
# ==========================================
#  Lightweight Utilities (zinit-managed)
# ==========================================

# mmv - File mover utility
zinit light-mode as'program' from'gh-r' for \
    pick'mmv*/mmv' @'itchyny/mmv'


# ==========================================
#  Productivity & Navigation Tools
# ==========================================

# navi - Interactive cheat sheet for terminal commands (Ctrl+N to search)
# navi installed via Homebrew, configuration and keybindings below
__navi_search() {
    local result
    if [[ -n "$TMUX" ]]; then
        local tmpfile
        tmpfile="$(mktemp)"
        # popupはPATHを引き継がないことがあるためnaviの絶対パスを渡す。
        # 選んで消えるものなので中央に 90%（packages/tmux/bin/tmux-popup）
        ~/.local/bin/tmux-popup center \
            "${commands[navi]} --print --fzf-overrides '--with-nth 2,3,1' --query=${(qq)LBUFFER} > ${(qq)tmpfile}"
        result="$(<"$tmpfile")"
        command rm -f -- "$tmpfile"
    else
        result="$(navi --print --query="$LBUFFER")"
    fi
    [[ -n "$result" ]] && LBUFFER="$result"
    zle reset-prompt
}
__setup_navi() {
    if command -v navi >/dev/null; then
        export NAVI_CONFIG="$XDG_CONFIG_HOME/navi/config.yaml"

        zle -N __navi_search
        # Alt+K。^N は emacs キーマップで履歴を1つ進めるキーなので譲る
        bindkey '^[k' __navi_search
    fi
}
__setup_navi

# forgit - Interactive git interface with fzf
__forgit_atload() {
    export FORGIT_INSTALL_DIR="$PWD"
    export FORGIT_NO_ALIASES=1
}
zinit light-mode as'program' for \
    atload'__forgit_atload' \
    pick'bin/git-forgit' \
    ver'main' \
    @'wfxr/forgit'

# zoxide - Smart directory jumping based on frequency (XDG compliant)
__zoxide_atload() {
    # XDG Base Directory compliance
    export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"   # Database location (persistent data)
    export _ZO_EXCLUDE_DIRS="$HOME"               # Exclude home directory from tracking
    export _ZO_RESOLVE_SYMLINKS=1                 # Resolve symlinks for consistency
    eval "$(zoxide init zsh)"
}
zinit light-mode as'program' from'gh-r' for \
    pick'zoxide*/zoxide' \
    atclone'./zoxide*/zoxide init zsh >init.zsh' atpull'%atclone' \
    atload'__zoxide_atload' \
    @'ajeetdsouza/zoxide'

# ==========================================
#  Modern CLI Replacements
# ==========================================

# fd completion is available via Homebrew at /opt/homebrew/share/zsh/site-functions/_fd

# bat completion is available via Homebrew at /opt/homebrew/share/zsh/site-functions/_bat

# ripgrep - Fast text search tool (installed via Homebrew)
# Completion available at /opt/homebrew/share/zsh/site-functions/_rg

# git-delta - Syntax-highlighting pager for git (installed via Homebrew)

