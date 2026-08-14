### locale ###
export LANG="en_US.UTF-8"

### XDG Base Directory ###
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

### zsh ###
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

### ghq ###
export GHQ_ROOT_PATH="$HOME/Repos"
export GHQ_GET_PATH="$GHQ_ROOT_PATH/github.com"

### homebrew ###
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_FILE="$XDG_CONFIG_HOME/homebrew/Brewfile"

# PATH の集約先は .zprofile だが、あれはログインシェルでしか読まれない。
# nix-darwin が生成する /etc/zshenv は全シェルで PATH を丸ごと上書きするため、
# 非ログインシェル（launchd 経由の skhd など）では /opt/homebrew/bin が消える。
# 実際 skhd から yabai が command not found になっていた。ここで最低限を補う。
# 順序は .zprofile と揃える（システムパスの後ろ）。
# TODO: Homebrew を Nix へ移すか、Home Manager で PATH を一元化するか検討する
typeset -U path
path=(
  "$path[@]"
  "/opt/homebrew/bin"(N-/)
  "/opt/homebrew/sbin"(N-/)
)

### Vim ###
# XDG Base Directory compliance for vim - forces vim to use ~/.config/vim/vimrc instead of ~/.vimrc
# Note: nvim also reads VIMINIT, so we use alias 'VIMINIT= nvim' to bypass this for nvim
export VIMINIT='let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | so $MYVIMRC'

### Node.js ###
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_history"

### npm ###
export NPM_CONF_DIR="$XDG_CONFIG_HOME/npm"  # NPM_CONFIG_* を避けた名前（npmが設定と誤解釈して警告を出すため）
export NPM_DATA_DIR="$XDG_DATA_HOME/npm"
export NPM_CACHE_DIR="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_USERCONFIG="$NPM_CONF_DIR/npmrc"
# NPM_DATA_DIR/bin の PATH追加は .zprofile（PATH集約先）へ移動

### Python ###
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/startup.py"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export PYLINTHOME="$XDG_CACHE_HOME/pylint"

### Rust ###
export RUST_BACKTRACE=1
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"

### Go ###
export GOPATH="$XDG_DATA_HOME/go"
export GO111MODULE="on"

### GnuPG ###
# WARNING: 秘密鍵が入りうるディレクトリ - dotfilesリポジトリには絶対に含めない
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

### Database Tools ###
export SQLITE_HISTORY="$XDG_STATE_HOME/sqlite_history"
export MYSQL_HISTFILE="$XDG_STATE_HOME/mysql_history"
export PSQL_HISTORY="$XDG_STATE_HOME/psql_history"

### mise ###
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"

### Bundle ###
export BUNDLE_USER_HOME="$XDG_CONFIG_HOME/bundle"
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME/bundle"
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME/bundle/plugin"

