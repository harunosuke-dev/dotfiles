#!/usr/bin/env bash
set -e
# shellcheck source=./scripts/common.sh

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# nvim リポジトリは事前に手動でクローンしておく（例: ghq get <owner>/nvim）
if ! is_dir "$GHQ_ROOT_PATH/github.com/$GITHUB_USER_NAME/nvim"; then
    log_warn "Nvim repository not found: $GHQ_ROOT_PATH/github.com/$GITHUB_USER_NAME/nvim"
    log_info "Clone it manually first - skipping nvim setup"
    exit 0
fi

# Handle existing ~/.config/nvim and create symlink
nvim_config_path="$XDG_CONFIG_HOME/nvim"
nvim_repo_path="$GHQ_ROOT_PATH/github.com/$GITHUB_USER_NAME/nvim"

# Check if nvim config already exists and is not our symlink
if [ -e "$nvim_config_path" ] && [ ! -L "$nvim_config_path" ]; then
    echo ""
    log_warn "Existing nvim configuration found at: $nvim_config_path"
    echo -n "❓ Backup existing config and replace with dotfiles nvim config? [y/N]: "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            log_step "BACKUP" "Backing up existing nvim configuration..."
            backup_file "$nvim_config_path"
            log_success "Existing nvim config backed up"

            log_step "LINK" "Creating symlink to nvim configuration..."
            safe_symlink "$nvim_repo_path" "$nvim_config_path"
            log_success "Nvim configuration symlink created"
            ;;
        *)
            log_info "Keeping existing nvim configuration - skipping setup"
            exit 0
            ;;
    esac
elif [ ! -L "$nvim_config_path" ] || [ "$(readlink "$nvim_config_path")" != "$nvim_repo_path" ]; then
    log_step "LINK" "Creating symlink to nvim configuration..."
    safe_symlink "$nvim_repo_path" "$nvim_config_path"
    log_success "Nvim configuration symlink created"
else
    log_info "Nvim configuration is already properly linked"
fi
