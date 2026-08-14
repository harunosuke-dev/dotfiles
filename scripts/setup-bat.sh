#!/usr/bin/env bash
set -e
# shellcheck source=./scripts/common.sh

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# bat は themes/ に置いた .tmTheme をそのままでは読まない。
# 一度キャッシュに焼き込む必要があり、これは環境ごとに1回要る。

if ! command_exists bat; then
    log_info "bat not installed - skipping theme cache"
    exit 0
fi

theme_dir="$XDG_CONFIG_HOME/bat/themes"
if ! is_dir "$theme_dir"; then
    log_info "No custom bat themes found - skipping theme cache"
    exit 0
fi

log_step "BUILD" "Building bat theme cache..."
bat cache --build >/dev/null
log_success "bat theme cache built"
