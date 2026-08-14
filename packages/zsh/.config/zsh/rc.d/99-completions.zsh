### Completion Settings ###
# zstyle は compinit の前後どちらで書いても効く（補完を実行する時に参照される）。
#
# menu の zstyle は書かない。zsh 既定の AUTO_MENU に任せる形で、
#   1回目の Tab  共通接頭辞まで補完する
#   2回目の Tab  候補を1つずつ挿入して巡る
# となる。以前は fzf-tab に候補選択を任せるため menu no を書いていた。
# 反転表示付きの一覧を出したい場合は menu select を書く
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
# Disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# Set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'

setopt COMPLETE_IN_WORD   # 語の途中でもカーソル位置を見て補完する
setopt ALWAYS_TO_END      # 補完したらカーソルを語末へ送る

### fzf のトリガー補完（nvim ** <Tab>）###
#   nvim ** <Tab>  → fzf のファイル検索
if (( $+widgets[fzf-completion] )); then
    fzf_default_completion=expand-or-complete
    bindkey '^I' fzf-completion
fi

### Utility functions ###
autoload -Uz zmv                    # Multi-move utility
autoload -Uz zargs                  # Extended xargs

### Completion functions ###
# Load completion functions safely
autoload -Uz _git 2>/dev/null           # Enable git completion
autoload -Uz _npm 2>/dev/null           # Enable npm completion
autoload -Uz _curl 2>/dev/null          # Enable curl completion
autoload -Uz _ssh 2>/dev/null           # Enable ssh completion
autoload -Uz _make 2>/dev/null          # Enable make completion (Makefile targets)
autoload -Uz _tar 2>/dev/null           # Enable tar completion
autoload -Uz _rsync 2>/dev/null         # Enable rsync completion
autoload -Uz _grep 2>/dev/null          # Enable grep completion
autoload -Uz _find 2>/dev/null          # Enable find completion
command -v brew >/dev/null && autoload -Uz _brew 2>/dev/null  # Enable brew completion if available

# ### Handle aliased commands ###
# # For commands that are aliased to other tools, ensure proper completion
# # This section handles cases where aliases override original commands

# # bat (aliased to cat) - use cat completion for bat
# if command -v bat >/dev/null && alias cat >/dev/null 2>&1; then
#     compdef _cat bat
# fi

# # eza (aliased to ls) - use ls completion for eza
# if command -v eza >/dev/null && alias ls >/dev/null 2>&1; then
#     compdef _ls eza
#     # Also handle specific eza aliases
#     compdef _ls la
#     compdef _ls ll
# fi

# # GNU tools on macOS (ggrep, gfind, etc.)
# if [[ "$OSTYPE" == darwin* ]]; then
#     command -v ggrep >/dev/null && alias grep >/dev/null 2>&1 && compdef _grep grep
#     command -v gfind >/dev/null && alias find >/dev/null 2>&1 && compdef _find find
#     command -v gls >/dev/null && compdef _ls gls
#     command -v gcp >/dev/null && alias cp >/dev/null 2>&1 && compdef _cp cp
#     command -v gmv >/dev/null && alias mv >/dev/null 2>&1 && compdef _mv mv
#     command -v grm >/dev/null && alias rm >/dev/null 2>&1 && compdef _rm rm
#     command -v gmkdir >/dev/null && alias mkdir >/dev/null 2>&1 && compdef _mkdir mkdir
#     command -v gdu >/dev/null && alias du >/dev/null 2>&1 && compdef _du du
#     command -v ghead >/dev/null && alias head >/dev/null 2>&1 && compdef _head head
#     command -v gtail >/dev/null && alias tail >/dev/null 2>&1 && compdef _tail tail
#     command -v gsed >/dev/null && alias sed >/dev/null 2>&1 && compdef _sed sed
#     command -v gdirname >/dev/null && alias dirname >/dev/null 2>&1 && compdef _dirname dirname
#     command -v gxargs >/dev/null && alias xargs >/dev/null 2>&1 && compdef _xargs xargs
# fi

# # trash (aliased to rm)
# if command -v trash >/dev/null && alias rm >/dev/null 2>&1; then
#     compdef _rm trash
# fi

# # mise (aliased to asdf)
# if command -v mise >/dev/null && alias asdf >/dev/null 2>&1; then
#     compdef _asdf asdf 2>/dev/null || true
# fi

### zinit 自身の補完 ###
# compinit は上で済ませてある。ここは _zinit を登録するだけ
if [[ -f "${ZINIT[HOME_DIR]}/completions/_zinit" ]]; then
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit
fi


