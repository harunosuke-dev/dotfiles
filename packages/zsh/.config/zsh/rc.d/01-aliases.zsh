### Aliases ###
# Basic aliases (will be overridden by eza if available)
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

case "$OSTYPE" in
    darwin*)
        alias pp='pbcopy'
        alias p='pbpaste'
        alias chrome='open -a "Google Chrome"'
        command -v gdate >/dev/null && alias date='gdate'
        command -v gls >/dev/null && alias ls='gls --color=auto'
        # Modern ls replacement - eza overrides gls if available
        if command -v eza >/dev/null; then
            alias ls='eza --group-directories-first --icons=auto'
            alias la='eza --group-directories-first -a'
            alias ll='eza --group-directories-first -al --header --color-scale=all --git --icons=auto --no-user --time-style=long-iso'
            alias tree='eza --group-directories-first -T --icons=auto'
            alias exa='eza'  # Legacy compatibility
        fi
        command -v gmkdir >/dev/null && alias mkdir='gmkdir'
        command -v gcp >/dev/null && alias cp='gcp -i'
        command -v gmv >/dev/null && alias mv='gmv -i'
        command -v grm >/dev/null && alias rm='grm -i'
        command -v gdu >/dev/null && alias du='gdu'
        command -v ghead >/dev/null && alias head='ghead'
        command -v gtail >/dev/null && alias tail='gtail'
        command -v gsed >/dev/null && alias sed='gsed'
        command -v ggrep >/dev/null && alias grep='ggrep'
        command -v gfind >/dev/null && alias find='gfind'
        command -v gdirname >/dev/null && alias dirname='gdirname'
        command -v gxargs >/dev/null && alias xargs='gxargs'
    ;;
    linux*)
        command -v wslview >/dev/null && alias open='wslview'

        if command -v win32yank.exe >/dev/null; then
            alias pp='win32yank.exe -i'
            alias p='win32yank.exe -o'
        elif command -v xsel >/dev/null; then
            alias pp='xsel -bi'
            alias p='xsel -b'
        fi
    ;;
    msys)
        alias cmake='command cmake -G"Unix Makefiles"'
        alias pp='cat >/dev/clipboard'
        alias p='cat /dev/clipboard'
    ;;
esac

command -v trash >/dev/null && alias rm='trash'
command -v mise >/dev/null && alias asdf='mise'

alias code='open -a "Visual Studio Code"'
alias gll='git log --graph --all --format="%x09%C(cyan bold)%an%Creset%x09%C(yellow)%h%Creset %C(magenta reverse)%d%Creset %s"'
alias gb='hub browse $(ghq list | fzf | cut -d "/" -f 2,3)'

### diff ###
diffb() { command diff "$@" | bat --paging=never --plain --language=diff; }
alias diffall='diffb --new-line-format="+%L" --old-line-format="-%L" --unchanged-line-format=" %L"'

### bat ###
# テーマは指定しない。bat の設定ファイル（packages/bat）で全体を揃えてある
alias cat='bat --paging=never'
alias batman='bat --language=man --plain'

### CMake ###
if command -v cmake >/dev/null; then
    alias cmaked='cmake -DCMAKE_BUILD_TYPE=Debug -B "$(git rev-parse --show-toplevel)/build"'
    alias cmakerel='cmake -DCMAKE_BUILD_TYPE=Release -B "$(git rev-parse --show-toplevel)/build"'
fi

### Make ###
alias make='make -j$(($(nproc)+1))'

### wget ###
command -v wget >/dev/null && alias wget='wget --hsts-file="$XDG_STATE_HOME/wget-hsts"'

# nvim: VIMINIT環境変数を無効化してinit.luaを使用
# .zshenv の VIMINIT は本物の vim に vim/vimrc を読ませるためのもの
# nvim も同じ変数を見てしまうため、ここで空にして init.lua を使わせる
alias nvim='VIMINIT= nvim'

# vim と打った時も nvim を開く（nvim が無い環境では素の vim のまま）
# vim を使いたい時は \vim または command vim
command -v nvim >/dev/null && alias vim='VIMINIT= nvim'

### Shell ###
# Full reload. Sourcing .zshrc cannot unload plugins or rerun .zshenv/.zprofile
alias reload='exec zsh -l'

### Package Management ###
# System-wide package update script
alias update='$HOME/.local/bin/update.sh'

# Dotfiles link management
alias setup-links='$HOME/.local/bin/setup-links.sh'

# Dotfiles health check (broken symlinks / dead configs / Brewfile drift)
alias doctor='$HOME/.local/bin/doctor.sh'

# zsh の履歴を 1Password へ退避・復元する（save / restore / diff）
alias history-vault='$HOME/.local/bin/history-vault.sh'

