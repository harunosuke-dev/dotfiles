#!/usr/bin/env bash

set -u

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

readonly NIX_PROFILE_SCRIPT="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
readonly NIX_BIN="/nix/var/nix/profiles/default/bin/nix"

load_nix_environment() {
    if [ -r "$NIX_PROFILE_SCRIPT" ]; then
        # shellcheck disable=SC1090
        source "$NIX_PROFILE_SCRIPT"
    fi
}

install_nix() {
    if command_exists nix || [ -x "$NIX_BIN" ]; then
        log_info "Nix is already installed"
        return 0
    fi

    if ! is_macos; then
        log_error "Nix bootstrap is only supported on macOS"
        return 1
    fi

    log_step "NIX" "Installing Nix in multi-user mode..."
    installer="$(mktemp -t dotfiles-nix-installer.XXXXXX)" || return 1
    if ! curl -fsSL https://nixos.org/nix/install -o "$installer"; then
        rm -f "$installer"
        log_error "Failed to download the Nix installer"
        return 1
    fi

    # nix-darwin will manage /etc/zshrc and related shell files.
    if ! NIX_INSTALLER_NO_MODIFY_PROFILE=1 NIX_INSTALLER_YES=1 \
        /bin/sh "$installer" --daemon; then
        rm -f "$installer"
        log_error "Nix installation failed"
        return 1
    fi
    rm -f "$installer"

    load_nix_environment
    if ! command_exists nix && [ ! -x "$NIX_BIN" ]; then
        log_error "Nix was installed but its executable was not found"
        return 1
    fi

    log_success "Nix installed"
}

resolve_configuration() {
    local config_names="$1"
    local local_hostname only_config

    if [ -n "${NIX_DARWIN_CONFIG:-}" ]; then
        printf '%s\n' "$NIX_DARWIN_CONFIG"
        return 0
    fi

    local_hostname="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)"
    if [ -n "$local_hostname" ] && \
        printf '%s\n' "$config_names" | grep -Fq "\"${local_hostname}\""; then
        printf '%s\n' "$local_hostname"
        return 0
    fi

    # 構成が1つだけなら、flake名をMac本体の名前とは独立した識別名として使う。
    only_config="$(printf '%s\n' "$config_names" | \
        sed -e 's/^\["//' -e 's/"\]$//')"
    if [ -n "$only_config" ] && [ "$only_config" != "[]" ] && \
        ! printf '%s\n' "$only_config" | grep -q '","'; then
        log_info "LocalHostName '$local_hostname' has no exact match; using the only configuration '$only_config'" >&2
        printf '%s\n' "$only_config"
        return 0
    fi

    return 1
}

prepare_nix_darwin_etc() {
    # 初回だけ、nix-darwinが管理する既存の通常ファイルを退避する。
    # シンボリックリンクなら既にnix-darwin管理下なので触らない。
    for path in /etc/zshrc /etc/zprofile /etc/bashrc /etc/bash_profile; do
        if [ -e "$path" ] && [ ! -L "$path" ]; then
            backup="${path}.before-nix-darwin"
            if [ -e "$backup" ]; then
                backup="${backup}.$(date +%Y%m%d_%H%M%S)"
            fi
            log_info "Backing up $path to $backup"
            sudo mv "$path" "$backup" || return 1
        fi
    done
}

apply_nix_darwin() {
    load_nix_environment
    if ! command_exists nix && [ ! -x "$NIX_BIN" ]; then
        log_error "Nix is not installed; nix-darwin cannot be applied"
        return 1
    fi

    nix_cmd="$(command -v nix 2>/dev/null || printf '%s' "$NIX_BIN")"
    config_names="$("$nix_cmd" --extra-experimental-features "nix-command flakes" \
        eval --json "${REPO_DIR}#darwinConfigurations" \
        --apply 'x: builtins.attrNames x' 2>/dev/null)" || {
        log_error "Failed to evaluate darwinConfigurations"
        return 1
    }

    config="$(resolve_configuration "$config_names")" || {
        local_hostname="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)"
        log_error "No nix-darwin configuration matches LocalHostName '$local_hostname'"
        log_info "Available configurations: $config_names"
        log_info "Set NIX_DARWIN_CONFIG explicitly or add this Mac to flake.nix"
        return 1
    }
    flake_ref="${REPO_DIR}#${config}"

    if ! printf '%s\n' "$config_names" | grep -Fq "\"${config}\""; then
        log_warn "No nix-darwin configuration named '$config'"
        log_info "Available configurations: $config_names"
        log_info "Set NIX_DARWIN_CONFIG explicitly or add this Mac to flake.nix"
        return 1
    fi

    configured_user="$("$nix_cmd" --extra-experimental-features "nix-command flakes" \
        eval --raw "${REPO_DIR}#darwinConfigurations.\"${config}\".config.system.primaryUser" 2>/dev/null)" || {
        log_error "Failed to read system.primaryUser from '$config'"
        return 1
    }
    current_user="$(id -un)"
    if [ "$configured_user" != "$current_user" ]; then
        log_warn "nix-darwin '$config' expects user '$configured_user', current user is '$current_user'"
        log_info "nix-darwin cannot be applied; the setup runner will continue with the remaining steps"
        return 1
    fi

    if [ "${NIX_DARWIN_DRY_RUN:-0}" = "1" ]; then
        log_success "Matched nix-darwin configuration '$config' for '$current_user'"
        return 0
    fi

    prepare_nix_darwin_etc || return 1
    log_step "NIX" "Applying nix-darwin configuration '$config'..."

    if [ -x /run/current-system/sw/bin/darwin-rebuild ]; then
        sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$flake_ref"
    else
        sudo "$nix_cmd" --extra-experimental-features "nix-command flakes" \
            run nix-darwin/master#darwin-rebuild -- \
            switch --flake "$flake_ref"
    fi
}

case "${1:-}" in
install)
    install_nix
    ;;
apply)
    apply_nix_darwin
    ;;
*)
    echo "Usage: $0 {install|apply}" >&2
    exit 2
    ;;
esac
