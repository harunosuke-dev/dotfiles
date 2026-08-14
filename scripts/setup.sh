#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/utils.sh"

# `curl ... | sh`でも、対話モードなら子スクリプトの入力を端末へ戻す。
if [ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ] && [ ! -t 0 ] && [ -t 1 ]; then
    exec </dev/tty || true
fi

readonly SKIP_EXIT_CODE=20
setup_failures=()
setup_skips=()
setup_successes=()

run_step() {
    local name="$1"
    shift

    echo ""
    log_step "$(( ${#setup_successes[@]} + ${#setup_skips[@]} + ${#setup_failures[@]} + 1 ))" "$name"
    local status
    if [ "${SETUP_DRY_RUN:-0}" = "1" ]; then
        printf '  [dry-run]'
        printf ' %q' "$@"
        printf '\n'
        status=0
    else
        "$@"
        status=$?
    fi

    # Ctrl-Cや終了要求は「失敗して続行」にはせず、セットアップ自体を止める。
    if [ "$status" -eq 130 ] || [ "$status" -eq 143 ]; then
        log_warn "$name interrupted"
        exit "$status"
    fi

    case "$status" in
    0)
        setup_successes+=("$name")
        log_success "$name completed"
        ;;
    "$SKIP_EXIT_CODE")
        setup_skips+=("$name")
        log_warn "$name skipped"
        ;;
    *)
        setup_failures+=("$name (exit $status)")
        log_error "$name failed; continuing with the remaining steps"
        ;;
    esac
}

print_summary() {
    echo ""
    echo "========================================"
    echo "Setup summary"
    echo "========================================"

    if [ ${#setup_successes[@]} -gt 0 ]; then
        log_success "Completed (${#setup_successes[@]})"
        printf '  - %s\n' "${setup_successes[@]}"
    fi
    if [ ${#setup_skips[@]} -gt 0 ]; then
        log_warn "Skipped (${#setup_skips[@]})"
        printf '  - %s\n' "${setup_skips[@]}"
    fi
    if [ ${#setup_failures[@]} -gt 0 ]; then
        log_error "Failed (${#setup_failures[@]})"
        printf '  - %s\n' "${setup_failures[@]}"
    fi
}

run_full_setup() {
    run_step "Install Nix" /bin/bash "$CUR_DIR/setup-nix.sh" install
    run_step "Install Homebrew packages" /bin/bash "$CUR_DIR/setup-homebrew.sh"
    run_step "Link dotfiles" /bin/bash "$CUR_DIR/../bin/setup-links.sh"
    run_step "Create local configuration" /bin/bash "$CUR_DIR/setup-local-config.sh"
    run_step "Apply nix-darwin" /bin/bash "$CUR_DIR/setup-nix.sh" apply
    run_step "Install APT packages" /bin/bash "$CUR_DIR/setup-apt.sh"
    run_step "Install mise tools" /bin/bash "$CUR_DIR/setup-mise.sh"
    run_step "Install zinit" /bin/bash "$CUR_DIR/setup-zinit.sh"
    run_step "Build bat theme cache" /bin/bash "$CUR_DIR/setup-bat.sh"
    run_step "Configure Neovim" /bin/bash "$CUR_DIR/setup-nvim.sh"
    run_step "Configure logins" /bin/bash "$CUR_DIR/setup-login.sh"
}

run_update_setup() {
    run_step "Update Homebrew packages" /bin/bash "$CUR_DIR/setup-homebrew.sh" --update
    run_step "Relink dotfiles" /bin/bash "$CUR_DIR/../bin/setup-links.sh"
    run_step "Apply nix-darwin" /bin/bash "$CUR_DIR/setup-nix.sh" apply
    run_step "Update mise tools" /bin/bash "$CUR_DIR/setup-mise.sh"
    run_step "Rebuild bat theme cache" /bin/bash "$CUR_DIR/setup-bat.sh"
}

case "${1:-full}" in
full)
    run_full_setup
    ;;
update)
    run_update_setup
    ;;
*)
    echo "Usage: $0 [full|update]" >&2
    exit 2
    ;;
esac

print_summary

if [ ${#setup_failures[@]} -gt 0 ]; then
    exit 1
fi

echo ""
echo "✨ All requested setup steps finished!"
