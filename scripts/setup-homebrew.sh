#!/usr/bin/env bash
set -e
# shellcheck source=./scripts/common.sh
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

if ! is_macos; then
    log_error 'This machine is not macOS!'
    exit 1
fi
[ -n "$SKIP_HOMEBREW" ] && exit
export SKIP_APT="true"

update_homebrew=0
skip_optional_apps=0
for option in "$@"; do
    case "$option" in
    -u | --update)
        update_homebrew=1
        skip_optional_apps=1
        ;;
    -s | --skip-apps)
        skip_optional_apps=1
        ;;
    -v | --verbose)
        ;;
    *)
        log_warn "Unknown option: $option"
        ;;
    esac
done

# Check prerequisites
log_step "PREREQ" "Checking prerequisites..."
check_internet || exit 1
check_xcode_tools

###########################################################
# Interactive Setup Configuration
###########################################################
# Default values
install_cask=0
install_vscode=0
install_mas=0

# Interactive prompts for optional components
log_step "SETUP" "🍺 Homebrew Setup Configuration"
log_info "Essential CLI tools will be installed automatically"
echo ""

if [ "$skip_optional_apps" -eq 1 ]; then
    log_info "Optional applications will be skipped"
elif [ -t 0 ]; then
    # Ask about GUI applications (cask)
    echo -n "❓ Install GUI applications (browsers, editors, etc.)? [y/N]: "
    read -r response || response=""
    case "$response" in
        [yY][eE][sS]|[yY]) install_cask=1 ;;
        *) log_info "GUI applications will be skipped" ;;
    esac

    # Ask about VSCode extensions
    echo -n "❓ Install VSCode extensions? [y/N]: "
    read -r response || response=""
    case "$response" in
        [yY][eE][sS]|[yY]) install_vscode=1 ;;
        *) log_info "VSCode extensions will be skipped" ;;
    esac

    # Ask about Mac App Store apps
    echo -n "❓ Install Mac App Store apps? [y/N]: "
    read -r response || response=""
    case "$response" in
        [yY][eE][sS]|[yY]) install_mas=1 ;;
        *) log_info "Mac App Store apps will be skipped" ;;
    esac
else
    log_info "Non-interactive input detected; optional applications will be skipped"
fi

echo ""
log_info "Configuration complete. Starting installation..."

# Note: Verbose mode (-v) is used by default for initial setup visibility

###########################################################
# Install Homebrew (Apple Silicon)
###########################################################
if command_exists brew; then
    log_info "Homebrew is already installed."
    if [ "$update_homebrew" -eq 1 ]; then
        log "🍺 Updating Homebrew..."
        brew update
    fi
else
    log 'Installing Homebrew for Apple Silicon...'
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    export PATH="/opt/homebrew/bin:$PATH"
    log "🍺 Updating Homebrew..."
    brew update
fi

###########################################################
# Create Filtered Brewfile
###########################################################
create_filtered_brewfile() {
    local source_file="$1"
    local target_file="$2"

    # Start with essential brew packages and taps
    grep -E '^(tap |brew )' "$source_file" > "$target_file"

    # Add cask packages if requested
    if [ "$install_cask" = 1 ]; then
        log_info "Including GUI applications (cask)"
        grep -E '^cask ' "$source_file" >> "$target_file"
    fi

    # Add VSCode extensions if requested
    if [ "$install_vscode" = 1 ]; then
        log_info "Including VSCode extensions"
        grep -E '^vscode ' "$source_file" >> "$target_file"
    fi

    # Add Mac App Store apps if requested
    if [ "$install_mas" = 1 ]; then
        log_info "Including Mac App Store apps"
        grep -E '^mas ' "$source_file" >> "$target_file"
    fi
}

###########################################################
# Install Apps and CLIs
###########################################################
log_step "INSTALL" "📌 Installing Selected Packages..."

# Determine source Brewfile
source_brewfile=""
if is_file "${REPO_DIR}/homebrew/Brewfile"; then
    log "Using local Brewfile: ${REPO_DIR}/homebrew/Brewfile"
    source_brewfile="${REPO_DIR}/homebrew/Brewfile"
elif curl -fsSL "https://raw.githubusercontent.com/${GITHUB_USER_NAME}/dotfiles/main/homebrew/Brewfile" -o /tmp/Brewfile.original 2>/dev/null; then
    log "Downloaded Brewfile from GitHub"
    source_brewfile="/tmp/Brewfile.original"
else
    log_error "Brewfile not found locally or on GitHub"
    log "Local path tried: ${REPO_DIR}/homebrew/Brewfile"
    log "GitHub URL tried: https://raw.githubusercontent.com/${GITHUB_USER_NAME}/dotfiles/main/homebrew/Brewfile"
    exit 1
fi

# Create filtered Brewfile based on user choices
filtered_brewfile="/tmp/Brewfile.filtered"
create_filtered_brewfile "$source_brewfile" "$filtered_brewfile"

# Install from filtered Brewfile
# 一部の失敗（App Store未サインインでのmas等）でセットアップ全体を止めない
log "Installing packages from filtered configuration..."
if ! brew bundle install --file "$filtered_brewfile" -v; then
    log_warn "Some packages failed to install (typical cause: not signed in to App Store)"
    log_info "Retry later with: brew bundle install --file ${REPO_DIR}/homebrew/Brewfile"
fi

# Cleanup temporary files
rm -f /tmp/Brewfile.original /tmp/Brewfile.filtered
log "Cleaned up temporary files"

true
