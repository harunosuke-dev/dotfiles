#!/bin/sh
set -e

# Error handling for install script
handle_install_error() {
    echo "❌ ERROR: Installation failed at line $1" >&2
    echo "📍 Please check the error message above and try again" >&2
    exit 1
}

trap 'handle_install_error $LINENO' ERR

GITHUB_USER_NAME=harunosuke-dev

DEFAULT_INSTALL_DIR="$HOME/.dotfiles"
RUNNING_FROM_REPO=0

# clone済みリポジトリのinstall.shを実行した場合は、その場所をそのまま使う。
# パイプ実行などで$0が実ファイルを指さない場合は、従来のGHQ配下を使用する。
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
if [ -f "$script_dir/install.sh" ] && [ -d "$script_dir/.git" ] && \
    [ -f "$script_dir/flake.nix" ]; then
    DEFAULT_INSTALL_DIR="$script_dir"
    RUNNING_FROM_REPO=1
fi

INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

###########################################################
# Pre-flight checks
###########################################################
echo "🔍 Running pre-flight checks..."

# Check if running on macOS
if [ "$(uname)" != "Darwin" ]; then
    echo "❌ ERROR: This script is designed for macOS only" >&2
    exit 1
fi

# Check internet connectivity (pingはICMP遮断ネットワークで誤検知するためcurlをフォールバックに)
if ! ping -c 1 google.com >/dev/null 2>&1 && ! curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; then
    echo "❌ ERROR: No internet connection available" >&2
    exit 1
fi

# Check for git
if ! command -v git >/dev/null 2>&1; then
    echo "⚠️  git is not installed. Attempting to install Command Line Tools..."
fi

# Check if Command Line Tools are already installed
if ! xcode-select -p >/dev/null 2>&1; then
    echo "📥 Installing Xcode Command Line Tools..."
    echo "   This will open a dialog - please click 'Install' and wait for completion."
    echo "   After installation completes, please re-run this script."
    echo ""

    # Trigger Command Line Tools installation
    xcode-select --install

    echo ""
    echo "⏳ Waiting for Command Line Tools installation..."
    echo "   Please complete the installation in the dialog that appeared."
    echo ""

    # Wait for installation to complete
    echo "🔄 Monitoring installation progress..."
    while ! xcode-select -p >/dev/null 2>&1; do
        echo "   Still installing... (checking every 10 seconds)"
        sleep 10
    done

    # Additional wait to ensure git is available
    echo "✅ Command Line Tools installation detected!"
    echo "⏳ Waiting a moment for tools to be fully available..."
    sleep 5

    # Verify git is now available
    if ! command -v git >/dev/null 2>&1; then
        echo "❌ ERROR: Installation completed but git is still not available"
        echo "   Please restart your terminal and run the script again"
        exit 1
    fi

    echo "✅ git is now available! Continuing with installation..."
    if ! command -v git >/dev/null 2>&1; then
        echo "❌ ERROR: Command Line Tools are installed but git is missing"
        echo "   Please check your installation or contact support"
        exit 1
    fi
fi

echo "✅ Pre-flight checks passed"

###########################################################
# Clone dotfiles from github.com
###########################################################
if [ ! -e "$INSTALL_DIR" ]; then
    echo "📌 Clone dotfiles..."
    git clone https://github.com/"$GITHUB_USER_NAME"/dotfiles --recursive "$INSTALL_DIR"
elif [ ! -d "$INSTALL_DIR/.git" ]; then
    echo "❌ ERROR: $INSTALL_DIR exists but is not a Git repository" >&2
    exit 1
elif [ "${DOTFILES_BOOTSTRAPPED:-0}" = "1" ]; then
    echo "📌 Using cloned dotfiles: $INSTALL_DIR"
else
    echo "📌 Updating dotfiles..."
    git -C "$INSTALL_DIR" pull
    [ -f "$INSTALL_DIR"/.gitmodules ] && git -C "$INSTALL_DIR" submodule update --init --recursive
fi

# `curl ... | sh`で起動した場合は、cloneしたリポジトリ内のスクリプトへ置き換える。
# 以降は通常ファイルから実行されるため、相対パス・対話入力・ブランチが明確になる。
if [ "$RUNNING_FROM_REPO" -eq 0 ] && [ "${DOTFILES_BOOTSTRAPPED:-0}" != "1" ]; then
    echo "🔄 Restarting installer from $INSTALL_DIR/install.sh"
    export DOTFILES_BOOTSTRAPPED=1
    exec /bin/sh "$INSTALL_DIR/install.sh"
fi

# ----------------------------------------------------------
# Determine setup mode (interactive or automated)
if [ -n "$BOOTSTRAP_MODE" ]; then
    # Non-interactive mode using environment variable
    setup_choice="$BOOTSTRAP_MODE"
    export DOTFILES_NONINTERACTIVE=1
    echo "🤖 Non-interactive mode: BOOTSTRAP_MODE=$BOOTSTRAP_MODE"
else
    # Interactive mode
    echo ""
    echo "🎯 Setup Options:"
    echo "  [1] Full setup (recommended for new machines)"
    echo "  [2] Update only (homebrew, packages, and basic maintenance)"
    echo "  [3] Skip setup (repository update only)"
    echo ""
    echo "💡 Tip: For automation, set BOOTSTRAP_MODE environment variable (1, 2, or 3)"
    echo ""

    # Default to full setup if no input provided
    printf "Choose an option [1]: "
    if [ -t 0 ]; then
        read -r setup_choice || setup_choice=""
    elif [ -t 1 ]; then
        read -r setup_choice </dev/tty || setup_choice=""
    else
        setup_choice=""
    fi

    # Set default value if empty
    setup_choice=${setup_choice:-1}
fi

case "$setup_choice" in
    1)
        echo "🚀 Running full setup..."
        /bin/bash "$INSTALL_DIR/scripts/setup.sh" full
        ;;
    2)
        echo "📦 Running update-only setup..."
        /bin/bash "$INSTALL_DIR/scripts/setup.sh" update
        ;;
    3)
        echo "⏭️  Setup skipped. Repository has been updated."
        ;;
    *)
        echo "❌ Invalid option. Running full setup as default..."
        /bin/bash "$INSTALL_DIR/scripts/setup.sh" full
        ;;
esac
