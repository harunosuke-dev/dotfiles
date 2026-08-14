#!/usr/bin/env bash
set -e
# shellcheck source=./scripts/common.sh
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

###########################################################
# GitHub CLI Login
###########################################################
log "Check GitHub auth status"
if ! gh auth status; then
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
        log_error "GitHub CLI is not authenticated and cannot prompt in non-interactive mode"
        log_info "Run 'gh auth login' and retry the setup"
        exit 1
    fi
    log 'Login with GitHub CLI'
    gh auth login
fi
