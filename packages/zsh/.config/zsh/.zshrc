#########################################################################
# ZSH CONFIGURATION - MAIN STARTUP FILE
#########################################################################
#
# This is the primary zsh configuration file, optimized for fast startup.
# Functions and complex settings are modularized in rc.d/ directory.
#
# LOADING ORDER:
# 1. Core Settings (paths, environment, options)
# 2. Plugin Manager Setup (zinit)
# 3. Essential Tools (mise, starship)
# 4. Key Bindings (immediate response required)
# 5. Lazy Loading (plugins via .zshrc.lazy)
# 6. Local Configuration (user customizations)
#
# KEYBINDING REFERENCE:
# emacs キーマップ（bindkey -e）。自作のウィジェットは Alt へ寄せ、制御キーは
# emacs 本来の編集キーと、fzf 由来で他所でも通じる3つだけに絞ってある。
#
# Basic Navigation & Editing（emacs の既定）:
# - Ctrl+A / Ctrl+E : 行頭 / 行末
# - Ctrl+B / Ctrl+F : 1文字 戻る / 進む
# - Ctrl+P / Ctrl+N : 履歴を 前 / 次
# - Ctrl+K / Ctrl+U : カーソルから行末まで / 行全体を削除
# - Ctrl+W          : 直前の単語を削除
# - Ctrl+Y          : 削除したものを貼り付け
# - Alt+B / Alt+F   : 単語単位で 戻る / 進む
# - Alt+.           : 直前のコマンドの最後の引数を挿入
# - Ctrl+X Ctrl+E   : 行全体を vim で編集
# - Ctrl+X Ctrl+U   : undo
#
# fzf Integration (fzf-key-bindings.zsh):
# - Ctrl+R : History search (custom widget / 02-functions.zsh)
# - Alt+C  : Directory selection widget
#
# Custom (02-functions.zsh):
# - Ctrl+Z : fz() - zoxide の履歴から cd
# - Alt+F  : tmux sessionizer (= tmux prefix + C-f)
# - Alt+G  : ghq repository -> tmux session
# - Alt+S  : tmux session switch (= tmux prefix + C-s)
# - Alt+K  : navi のチートシート（04-plugins.zsh）
# - cdg    : ghq repository -> cd（コマンド。インラインの fzf）
#
# tmux セッションの削除は tmux 側の prefix + C-x のみ。
#
# Completion (zsh 標準 compinit のみ。zsh-autocomplete と fzf-tab は外した):
# - Tab        : 共通接頭辞まで補完。もう一度押すとメニューへ入り候補を巡る
# - Tab (**)   : fzf のトリガー補完（例: nvim ** <Tab>）
# - Up / Down  : 履歴を時系列で辿る（zsh 既定の up/down-line-or-history）
# - Ctrl+P / N : カーソルまでの文字列で履歴を絞る
# - Ctrl+R     : 履歴を fzf で検索（widget::history）
# - Right      : ゴーストテキスト（zsh-autosuggestions）を受け入れる
#
#########################################################################

# ==========================================
#  Core Environment Setup
# ==========================================

### zinit plugin manager ###
typeset -gAH ZINIT
ZINIT[HOME_DIR]="$XDG_DATA_HOME/zinit"
ZINIT[ZCOMPDUMP_PATH]="$XDG_STATE_HOME/zsh/zcompdump"

# Check if zinit is installed, show warning if not
if [[ ! -d "${ZINIT[HOME_DIR]}/bin" ]]; then
    echo "⚠️  Warning: zinit not found. Run 'setup-zinit' to install."
    return 1
fi

source "${ZINIT[HOME_DIR]}/bin/zinit.zsh"

### fpath (completion function search path) ###
# PATH本体は .zprofile で確定する。ここは補完(compinit)用の fpath のみ。
typeset -U fpath

fpath=(
  "$XDG_CONFIG_HOME/zsh/completions"(N-/)
  "$XDG_DATA_HOME/zsh/completions"(N-/)
  "$fpath[@]"
  /opt/homebrew/share/zsh/site-functions(N-/)
)

### Environment Variables ###
# Man pages
export MANPATH="$HOME/.local/share/man/dotfiles:$MANPATH"

# History configuration
export HISTFILE="$XDG_STATE_HOME/zsh/history"
# 履歴は 1Password へ退避して新しい環境へ持ち込む前提（bin/history-vault.sh）
export HISTSIZE=1100000
export SAVEHIST=1000000

# Editor preferences
export EDITOR="vi"
command -v vim >/dev/null && EDITOR="vim"
command -v nvim >/dev/null && EDITOR="nvim"
# コミットメッセージのような使い捨ての編集は軽量なvimで開く。
command -v vim >/dev/null && export GIT_EDITOR="vim"
export TERMINAL="ghostty"
# export BROWSER="brave"

### Shell Options ###
setopt NO_BEEP
setopt IGNOREEOF
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt GLOBDOTS
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY
# setopt NO_SHARE_HISTORY
setopt MAGIC_EQUAL_SUBST
setopt PRINT_EIGHT_BIT
setopt NO_FLOW_CONTROL

# ==========================================
#  Runtime Tools
# ==========================================

### Runtime tool manager ###
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

### Prompt (Starship) ###
# Load starship early for immediate prompt display
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"
if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
else
    echo "⚠️  Warning: starship not found. Install with 'brew install starship'"
fi

# ==========================================
#  Key Bindings
# ==========================================

# 端末のフロー制御を切る
[[ -t 0 ]] && stty -ixon

# emacs キーマップ - 明示が必須で、消すと vi モードに戻る
bindkey -e

# Essential key bindings (functions defined in 02-functions.zsh)
bindkey "^R" widget::history            # C-r
bindkey "^[g" widget::ghq::session      # Alt-g: ghq のリポジトリで tmux セッション

# プロンプトを vim で編集する。EDITORはnvimのままなので、ここでだけ差し替える
autoload -Uz edit-command-line
zle -N edit-command-line

_edit_command_line_vim() {
    local -x EDITOR=vim
    zle edit-command-line
}
zle -N _edit_command_line_vim
bindkey "^X^E" _edit_command_line_vim  # C-x C-e

# C-x を押した時に「次のキー待ち」だと分かるようにする：
#   1. プロンプト直下のステータス行に C-x- と出す（次のキーを押すまで表示）
#   2. 次のキーを1つ読む
#   3. bindkey で ^X<キー> の割り当てを引いて、そのウィジェットを呼ぶ
_ctrl_x_prefix() {
    zle -R "C-x-"

    local key
    read -k 1 key

    local widget="${${(z)"$(bindkey "^X${key}")"}[-1]}"
    if [[ -z "$widget" || "$widget" == undefined-key ]]; then
        zle -R ""
        zle beep
        return
    fi

    zle -R ""
    zle "$widget"
}
zle -N _ctrl_x_prefix
bindkey "^X" _ctrl_x_prefix

# 履歴の絞り込み。カーソルまでの文字列で前方一致する。
# 矢印キーは既定（up/down-line-or-history）のまま触らない。あちらは時系列を
bindkey "^P" history-beginning-search-backward   # C-p
bindkey "^N" history-beginning-search-forward    # C-n

# 以下は emacs の既定と同じ内容 - 明示しておくと一覧として読める
bindkey "^A" beginning-of-line          # C-a
bindkey "^E" end-of-line                # C-e
bindkey "^K" kill-line                  # C-k
bindkey "^Q" push-line-or-edit          # C-q
bindkey "^W" backward-kill-word         # C-w
bindkey "^?" backward-delete-char       # backspace
bindkey "^[[3~" delete-char             # delete
bindkey "^[[1;3D" backward-word         # Alt + arrow-left
bindkey "^[[1;3C" forward-word          # Alt + arrow-right
bindkey "^[^?" backward-kill-word       # Alt + backspace
bindkey "^[[1;33~" kill-word            # Alt + delete

# ==========================================
#  Plugin System
# ==========================================
# compinit の呼び出しは rc.d/99-completions.zsh にある。fpath が出揃った後で
# なければ拾えないので、プラグインを読む 04 より後に置く必要がある。
# ここではダンプの場所だけ決めておく（既定は $XDG_CACHE_HOME/zsh/compdump）。
typeset -g _comp_dumpfile="$XDG_STATE_HOME/zsh/zcompdump-$ZSH_VERSION"

### Module Loading ###
# Load modular configurations synchronously to ensure proper plugin order
for config in "$ZDOTDIR"/rc.d/*.zsh; do
    [[ -r "$config" ]] && source "$config"
done

# ==========================================
#  Local Configuration
# ==========================================

### User-specific Settings ###
# Load local configuration if exists (not tracked by git)
[ -f "$ZDOTDIR/.zshrc.local" ] && source "$ZDOTDIR/.zshrc.local"

#########################################################################
# END OF CONFIGURATION
#########################################################################

