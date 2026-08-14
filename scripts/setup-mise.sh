#!/usr/bin/env bash
set -e
# shellcheck source=./scripts/common.sh
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"

# Initial setup script for mise - no options needed

###########################################################
# Install mise
###########################################################
if command -v mise >/dev/null 2>&1; then
    log "mise is already installed."
elif [ "$(uname)" = "Darwin" ]; then
    log "Installing mise via homebrew..."
    brew install mise
else
    log "Installing mise via official installer..."
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# -------------------------------------------------------------------------
### Install development tools
log_step "INSTALL" "Installing development tools via mise..."
log_info "Using global configuration: ~/.config/mise/config.toml (via symlink)"

# Execute from home directory to ensure global config is used
if (cd "$HOME" && mise install); then
    log_success "All development tools installed successfully"
else
    log_warn "Some tools may have failed to install (check manually with 'mise doctor')"
fi
