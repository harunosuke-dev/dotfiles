# Setup fzf
# Note: fzf functions have been moved to ~/.config/zsh/rc.d/02-functions.zsh

FZF_HOME="${FZF_HOME:-/opt/homebrew/opt/fzf}"

# PATH 本体は .zprofile で確定する - ここでは fzf 同梱の bin だけを補う
if [[ -d "$FZF_HOME/bin" && ! "$PATH" == *"$FZF_HOME/bin"* ]]; then
    PATH="${PATH:+${PATH}:}$FZF_HOME/bin"
fi

# Auto-completion
if [[ $- == *i* && -r "$FZF_HOME/shell/completion.zsh" ]]; then
    source "$FZF_HOME/shell/completion.zsh"
fi

# Key bindings
source "${XDG_CONFIG_HOME}/fzf/fzf-key-bindings.zsh"

#########################################################################
# settings
#########################################################################
export FZF_COMPLETION_TRIGGER='**' # default: '**'
export FZF_TMUX=1
export FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git/*' -g '!node_modules/*'"

### --- 配色 --- ###
__FZF_COLORS="--color=fg:#959da5,bg:-1,hl:#79b8ff"
__FZF_COLORS+=",fg+:#f6f8fa,bg+:#2f363d,hl+:#79b8ff"
__FZF_COLORS+=",info:#959da5,prompt:#79b8ff,pointer:#ea4a5a"
__FZF_COLORS+=",marker:#7bcc72,spinner:#b392f0,header:#959da5"
__FZF_COLORS+=",border:#444d56,preview-bg:-1"

### --- キー割り当ての方針 --- ###
# ctrl-n/p は候補の選択移動（fzf の既定）のまま触らない。
# Vim で <C-n>/<C-p> が補完候補の next/previous であること、nvim 側の fzf-lua も既定のままであることと揃う。
#
# プレビューのページ送りは ctrl-u/d - Vim の半ページスクロールと同じ
# nvim の fzf-lua（lua/plugins/finder.lua）でも同じキー

### --- FZF_TMUX_OPTS, FZF_DEFAULT_OPTS --- ###
if [[ -n ${TMUX-} ]]; then
    __FZF_CMD="fzf-tmux"
    __FZF_CMD_OPTS=(
        -p
        90%
    )

    export FZF_DEFAULT_OPTS="$(
        cat <<"EOF"
--preview '
  ( (type bat > /dev/null) &&
    bat --color=always --line-range :200 {} \
    || (cat {} | head -200) ) 2> /dev/null
'
EOF
    ) \
        --layout=reverse --border --ansi \
        $__FZF_COLORS \
        --preview-window 'right,50%,nowrap' \
        --header 'Ctrl-\: Toggle Preview | Ctrl-U/D: Page Up/Down' \
        --bind 'Ctrl-\:toggle-preview' \
        --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down'"

    # 幅・高さの両方を指定して中央90%で表示（幅だけ指定だと高さが半端で上寄りになる）。
    # fzfピッカー（fz/find_cd/ghq/セッション切替・削除/履歴/^Fセッション選択）に効く。
    #
    # -y はステータスラインを除いた領域の中央に置く。既定では上1行・下4行
    # と上に寄っていた（53行の画面の場合）。
    #
    # 注意が2つある。
    #
    #   1. tmux の -y は popup の「下端」の行を指す（-x は左端）。上端を
    #      渡すと popup が画面に収まらず、上端へ押し戻されて無視される。
    #   2. popup_height は -y の評価時点ではまだ空。-h と同じ 90% から
    #      自分で出す。
    #
    #   上端 = 1 + (client_height - 1 - popup_height) / 2
    #   下端 = 上端 + popup_height
    #
    # 画面の大きさが変わっても tmux が計算し直す。先頭の 1 は
    # ステータスラインの行数で、status-position top が前提
    __FZF_POPUP_H='#{e|/:#{e|*:#{client_height},90},100}'
    __FZF_POPUP_TOP="#{e|+:1,#{e|/:#{e|-:#{e|-:#{client_height},1},${__FZF_POPUP_H}},2}}"
    export FZF_TMUX_OPTS="-p 90%,90% -y#{e|+:${__FZF_POPUP_TOP},${__FZF_POPUP_H}}"

else

    __FZF_CMD="fzf"
    __FZF_CMD_OPTS=()

    export FZF_DEFAULT_OPTS="$(
        cat <<"EOF"
    --preview '
          ( (type bat > /dev/null) &&
            bat --color=always --line-range :200 {} \
            || (cat {} | head -200) ) 2> /dev/null
        '
EOF
    ) \
                --height '~60%' --min-height 10 --layout=reverse --border=none --info=inline --ansi \
                $__FZF_COLORS \
                --preview-window 'right,50%,nowrap' \
                --header 'Ctrl-\: Toggle Preview | Ctrl-U/D: Page Up/Down' \
                --bind 'ctrl-\:change-preview-window(hidden|)' \
                --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down'"
fi

### --- fzf 本体 --- ###
# 素の fzf も tmux の popup で開き、プレビューは畳んでおく。
fzf() {
  local -a cmd
  cmd=( ${=$(__fzfcmd)} )
  command "${cmd[@]}" --preview-window 'hidden' "$@"
}

### --- トリガー補完（** <Tab>）が候補を集めるコマンド --- ###
# fzf の補完はこの2つが定義されていれば最優先で使い、結果を標準入力へ流す。
#
# 定義しないと fzf 内蔵の walker（--walker-root で対象を指定する仕組み）に
# 落ちるが、そちらは FZF_DEFAULT_COMMAND が設定されていると無視される。
# その結果 cd ~/Repos/**<Tab> のように場所を指定しても、指定先ではなく
# cwd のファイル一覧が出てしまう。
#
# walker はもう一つ、cd の補完で隠しディレクトリを出さない（dir,follow のみで
# hidden が付かない）。~/.config へ飛べないので fd の --hidden で揃える。
_fzf_compgen_path() {
    fd --hidden --follow --exclude .git --exclude node_modules . "$1"
}

_fzf_compgen_dir() {
    fd --type d --hidden --follow --exclude .git --exclude node_modules . "$1"
}

### --- トリガー補完（** <Tab>）が使う起動口 --- ###
_fzf_comprun() {
  shift
  if [[ -n ${TMUX-} ]]; then
    fzf-tmux ${=FZF_TMUX_OPTS} -- "$@"
  else
    command fzf "$@"
  fi
}

### --- options --- ###
export FZF_CTRL_R_OPTS=$(
    cat <<"EOF"
--preview '
  echo {} \
  | awk "{ sub(/^[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+/, \"\"); gsub(/\\\\n/, \"\\n\"); print }" \
  | bat --color=always --language=sh --style=plain
'
--preview-window 'down,30%,hidden,wrap'
EOF
)
