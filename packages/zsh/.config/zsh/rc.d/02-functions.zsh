#########################################################################
# FUNCTIONS - Custom shell functions and widgets
#########################################################################
#
# This file contains custom functions and zsh widgets with keybindings.
# Functions are organized by category for better maintainability.
#
# KEYBINDINGS SUMMARY:
# tmux と同じ文字が同じ機能を指すように揃えてある。tmux は prefix + Ctrl+英字、
# zsh は Ctrl+英字だけ。Alt は skhd が OS 全体で横取りするので使わない。
#
# - Ctrl+R : widget::history() - fzf の履歴検索
# - Ctrl+Z : fz() - zoxide の履歴から cd（emacs キーマップで空き）
# - Ctrl+O : tmux sessionizer（= tmux prefix + C-o, popup）
# - Ctrl+S : tmux session switch（= tmux prefix + C-s, popup）
# - Alt+K : __navi_search - navi のチートシート（04-plugins.zsh）
#
# emacs の編集キーは明け渡さない。Ctrl+A/B/E/F/N/P/Y/K/W/U と、
# プレフィックスの Ctrl+X はそのまま残す。
# Ctrl+S は .zshrc の stty -ixon でフロー制御を切ってあるので使える。
#
# lazygit（prefix + C-g）とセッション削除（prefix + C-x）は tmux 側のみ。
# 長く滞在するものと破壊的なものには、zsh 側に1打鍵の入口を置かない
#
# COMMANDS (not widgets):
# - cdg : ghq repository -> cd (inline fzf)
#
#########################################################################

### Basic utility functions ###

# History filtering + skip failed commands
# 名前で常に除外する汎用/破壊系コマンド（追加したい語はここに足す）
_hist_ignore_re='^(z|which|type|whence|history|jj?|lazygit|la|ll|ls|rm|rmdir|trash|pwd|clear|exit)($| )'

# HIST_IGNORE_SPACE（先頭にスペースを打つと記録されない）も有効にしてあるが、
# あちらは打つ前に思い出す必要がある。こちらは忘れても効く。
_hist_secret_re='(--?(password|passwd|token|secret|api[-_]?key)|Bearer |PRIVATE KEY|[A-Za-z_]*(KEY|TOKEN|SECRET|PASSWORD)=)'

# precmd で終了ステータスを見て「成功したコマンドだけ」履歴に確定する。
zshaddhistory() {
  local line="${1%%$'\n'}"
  # 下の確定は print -sr で履歴へ直接積むため HIST_IGNORE_SPACE を通らない。
  # 行頭アンカーの除外も素通りしてしまうので、空白始まりはここで落とす
  [[ "$line" == [[:space:]]* ]] && return 1       # 先頭に空白がある行を除外
  [[ "$line" =~ $_hist_ignore_re ]] && return 1   # 名前で除外
  [[ "$line" =~ $_hist_secret_re ]] && return 1   # 秘密が混じりうる行を除外

  if [[ "$line" == 'exec '* || "$line" == 'reload' ]]; then
    print -sr -- "$line"
    return 1
  fi
  _hist_pending="$line"
  # いったん保存を保留（成功時のみ確定）
  return 1                                         }

_hist_commit_on_success() {
  local st=$?
  [[ -n "$_hist_pending" && $st -eq 0 ]] && print -sr -- "$_hist_pending"
  _hist_pending=""
  return $st
}

(( ${precmd_functions[(Ie)_hist_commit_on_success]} )) || precmd_functions=(_hist_commit_on_success $precmd_functions)


### zsh Widget Functions ###

# Clear screen with prompt update
clear-screen-and-update-prompt() {
    # ALMEL_STATUS=0
    # almel::precmd
    zle .clear-screen
}
zle -N clear-screen clear-screen-and-update-prompt

# History search widget using fzf
# NOTE: 番号は !13 で再実行できる（ただしシェルごとのイベント番号）
widget::history() {
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
    local selected=( "$(history -r 1 \
        | awk '{ n = $1; sub(/^ *[0-9]+ +/, ""); printf "[%s] %s\n", n, $0 }' \
        | FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-} --scheme=history ${FZF_CTRL_R_OPTS-} \
        --prompt 'History> ' --exit-0 --nth=2.. --query '$LBUFFER'" $(__fzfcmd) \
        | sed 's/^\[[0-9]*\] //' | sed 's/\\n/\n/g')" )
    if [ -n "$selected" ]; then
        BUFFER="$selected"
        CURSOR=$#BUFFER
    fi
    zle reset-prompt
}


### ghq ###

# ghq のリポジトリへ cd するコマンド。
# セッションを張りたい相手は tmux-sessionizer の探索パスに入っているので、
# こちらは cd だけを担う
cdg() {
    local repo
    repo="$(ghq list | sort | command fzf \
        --height='~60%' --min-height=8 \
        --layout=reverse --border=none --info=inline \
        --no-preview --header='' \
        --prompt='Repository> ')"
    [[ -n "$repo" ]] && cd "$(ghq list --exact --full-path "$repo")"
}


### Widget Registration ###
zle -N widget::history

### カーソルの形 ###
_cursor_line() {
    printf '\033[6 q'
}

zle-line-init() { _cursor_line }
zle-line-finish() { _cursor_line }

zle -N zle-line-init
zle -N zle-line-finish

mkcd() {
    # Create directory and change into it
    command mkdir -p -- "$@" && builtin cd "${@[-1]:a}"
}


#########################################################################
# DIRECTORY NAVIGATION
#########################################################################

### fzf-enhanced navigation ###

# Ctrl+Z から呼ぶウィジェットだが、fz と打っても使える。
# $WIDGET は ZLE がウィジェットを実行している間だけ設定される。
# 見ないと zle の呼び出しが「widgets can only be called when ZLE is active」で落ちる
fz() {
    # Smart directory jump using zoxide (Ctrl+Z)
    if ! command -v zoxide >/dev/null 2>&1; then
        # ウィジェットの中では echo が行を割り込ませて表示を崩す
        if [[ -n "${WIDGET-}" ]]; then
            zle -M "zoxide not available"
        else
            print -u2 "zoxide not available"
        fi
        return 1
    fi

    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2>/dev/null
    local res=$(zoxide query --list --score | sort -nr | awk '{$1=""; print substr($0,2)}' | FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-}" \
        $(__fzfcmd) --preview "echo {} | xargs eza \
        --color=always -h --long --icons --classify --git --no-permissions --no-user --no-filesize --git-ignore --sort modified --reverse --tree --level 4")
    if [ -n "$res" ]; then
        if [[ -n "${WIDGET-}" ]]; then
            BUFFER+="cd $res"
            zle accept-line
        else
            builtin cd "$res"
        fi
    else
        [[ -n "${WIDGET-}" ]] && zle reset-prompt
        return 1
    fi
}
zle -N fz
bindkey '^Z' fz


### Git repository navigation ###

j() {
    # Fuzzy directory jump within git repository
    local root dir
    # --show-cdup はルートまでの相対パスを返し、ルート直下では空になる。
    # zsh では ${$(cmd):-.} と書けないので2行に分ける
    root="$(git rev-parse --show-cdup 2>/dev/null)"
    root="${root:-.}"
    dir="$(fd --color=always --hidden --type=d . "$root" | fzf --select-1 --query="$*" --preview='fzf-preview-directory {}')"
    if [ -n "$dir" ]; then
        builtin cd "$dir"
        echo "$PWD"
    fi
}

jj() {
    # Jump to git repository root
    local root
    root="$(git rev-parse --show-toplevel)" || return 1
    builtin cd "$root"
}


#########################################################################
# BUILD TOOLS - CMake utilities
#########################################################################

cmakeb() {
    # Build project using cmake
    build_dir=${1:-$(git rev-parse --show-toplevel)/build}
    shift || true
    cmake --build "$build_dir" -j"$(($(nproc) + 1))" "$@"
}

cmaket() {
    # Run ctest in specified directory
    test_dir=${1:-$(git rev-parse --show-toplevel)/build}
    shift || true
    ctest --verbose --test-dir "$test_dir" "$@"
}


#########################################################################
# TMUX INTEGRATION - Session management
#########################################################################

# tmux.conf の prefix + C-o と同じもの（Ctrl+O）
tmux_sessionizer_popup() {
    if [[ -n "$TMUX" ]]; then
        ~/.local/bin/tmux-popup center ~/.local/bin/tmux-sessionizer-popup
        zle reset-prompt
        return
    fi

    # tmux の外では popup を開けない。スクリプト末尾の
    # exec tmux new-session -A -D を ZLE の中で走らせると
    # 「open terminal failed: not a terminal」で attach に失敗するので、
    # コマンドラインへ積んで通常の前景プロセスとして起動する
    # 先頭の空白は zshaddhistory が見て履歴から落とす。
    # 入った先が分かるわけでもないスクリプト名を残しても意味がない
    BUFFER=" ~/.local/bin/tmux-sessionizer-popup"
    zle accept-line
}
zle -N tmux_sessionizer_popup
bindkey '^O' tmux_sessionizer_popup

# tmux.conf の prefix + C-s と同じセッション切替（Ctrl+S）
tmux_choose_session() {
    if [[ -n "$TMUX" ]]; then
        ~/.local/bin/tmux-popup center ~/.local/bin/tmux-switch-session
        zle reset-prompt
        return
    fi

    local sessions selected
    sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | sort)
    if [[ -z "$sessions" ]]; then
        zle -M "No tmux sessions available"
        return 1
    fi

    # 大きさと枠は FZF_DEFAULT_OPTS に任せて他のウィジェットと揃える。
    # セッション名はファイルではないのでプレビューだけ切る
    selected=$(print -r -- "$sessions" | command fzf \
        --no-preview --header='' \
        --prompt='Attach to session: ')

    if [[ -n "$selected" ]]; then
        # 先頭の空白で履歴から落とす。attach-session は既存のセッションにしか
        # 繋げないので、消えた後の名前が履歴に残っていても引き当てられない
        BUFFER=" tmux attach-session -t ${(q)selected}"
        zle accept-line
        return
    fi
    zle reset-prompt
}
zle -N tmux_choose_session
bindkey '^S' tmux_choose_session


#########################################################################
# FILE MANAGEMENT
#########################################################################

### Editor integration ###

e() {
    # Enhanced editor function with fzf file selection
    if [ $# -eq 0 ]; then
        local selected="$(fd --hidden --color=always --type=f  | fzf --exit-0 --multi --preview="fzf-preview-file {}" --preview-window="right:60%")"
        if [ -n "$selected" ]; then
            if [[ "$EDITOR" == "nvim" ]]; then
                VIMINIT= "$EDITOR" -- ${(f)selected}
            else
                "$EDITOR" -- ${(f)selected}
            fi
        fi
    else
        if [[ "$EDITOR" == "nvim" ]]; then
            VIMINIT= "$EDITOR" "$@"
        else
            "$EDITOR" "$@"
        fi
    fi
}


#########################################################################
# COMMAND NAVIGATION (navi)
#########################################################################

# navi: チートシートから選んでプロンプトに貼る
if command -v navi >/dev/null; then
    navi() {
        local cmd
        cmd="$(command navi --print "$@" </dev/tty)" || return
        [[ -n "$cmd" ]] && print -z -- "$cmd"
    }
fi


#########################################################################
# DOCKER UTILITIES (commented out)
#########################################################################

# These Docker helper functions are commented out but available if needed.
# Uncomment and modify as required for your Docker workflow.
# docker() {
#     if [ "$#" -eq 0 ] || [ "$1" = "compose" ] || ! command -v "docker-$1" >/dev/null; then
#         command docker "${@:1}"
#     else
#         "docker-$1" "${@:2}"
#     fi
# }

# docker-clean() {
#     command docker ps -aqf status=exited | xargs -r docker rm --
# }
# docker-cleani() {
#     command docker images -qf dangling=true | xargs -r docker rmi --
# }
# docker-rm() {
#     if [ "$#" -eq 0 ]; then
#         command docker ps -a | fzf --exit-0 --multi --header-lines=1 | awk '{ print $1 }' | xargs -r docker rm --
#     else
#         command docker rm "$@"
#     fi
# }
# docker-rmi() {
#     if [ "$#" -eq 0 ]; then
#         command docker images | fzf --exit-0 --multi --header-lines=1 | awk '{ print $3 }' | xargs -r docker rmi --
#     else
#         command docker rmi "$@"
#     fi
# }

