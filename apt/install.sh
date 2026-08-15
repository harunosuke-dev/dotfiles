#!/bin/bash
set -eu

### PPA support
# 最小構成のUbuntuには add-apt-repository が無いため先に入れる
apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:git-core/ppa
apt-get update
apt-get upgrade -y

### Core development and system packages
packages=(
    bat             # Cat clone with syntax highlighting
    build-essential # Essential build tools (gcc, make, etc.)
    cmake           # Cross-platform build system
    curl            # Command line tool for transferring data with URLs
    direnv          # Environment switcher for the shell
    fd-find         # Simple, fast and user-friendly alternative to find
    fzf             # Command-line fuzzy finder
    git             # Distributed version control system
    git-lfs         # Git extension for versioning large files
    gpg             # GNU Privacy Guard - encryption and signing
    jq              # Lightweight and flexible command-line JSON processor
    neovim          # Hyperextensible Vim-based text editor
    openssh-client  # SSH client (git over SSH に必須。最小構成だと入っていない)
    ripgrep         # Recursively searches directories for regex patterns
    rsync           # Fast, versatile, remote (and local) file-copying tool
    shellcheck      # Shell script analysis tool
    stow            # Symlink manager for dotfiles
    tmux            # Terminal multiplexer
    tree            # Displays directories as trees
    unzip           # De-archiver for .zip files
    wget            # Retrieves files from the web
    xz-utils        # XZ decompression (mise が Node の .tar.xz を展開するのに使う)
    zsh             # Shell with lots of features
    libbz2-dev      # 以下7つは mise が Python をソースビルドするのに必要
    libffi-dev      #
    liblzma-dev     #
    libreadline-dev #
    libsqlite3-dev  #
    libssl-dev      #
    zlib1g-dev      # 上記Pythonビルド依存の残り1つ
)

# 必要になったら有効化する候補（配列の外に置く。中に混ぜると整形時に列がずれる）
#   gdb clangd                 C言語のデバッグとLSP。コンパイラ自体は build-essential の gcc で足りる

apt-get install -y "${packages[@]}"

### Docker installation
# curl -fsSL 'https://download.docker.com/linux/ubuntu/gpg' | apt-key add -
# add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# apt-get update
# apt-get install -y docker-ce docker-ce-cli

### eza (modern ls replacement)
# Ubuntu標準リポジトリに無いため、eza公式のaptリポジトリを追加する
mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
    gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    >/etc/apt/sources.list.d/gierens.list
chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list

apt-get update
apt-get install -y eza
