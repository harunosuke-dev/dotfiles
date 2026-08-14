#!/bin/sh

###########################################################
# System Update Script
###########################################################
# Updates all package managers: Homebrew, zinit, and mise
# Usage: ./bin/update.sh [--dry-run] [--force]

# Load utils for logging functions
# symlink経由（~/.local/bin/update.sh）でも実体を解決できるよう readlink -f を使う
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
. "$SCRIPT_DIR/../scripts/utils.sh"

# Configuration
DRY_RUN=false
FORCE=false
MANAGER_ONLY=false
PACKAGES_ONLY=false
ALL_MANAGERS=false
LOG_FILE="$HOME/.local/state/system-update.log"
SELECTED_MANAGERS=""

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --manager-only)
            MANAGER_ONLY=true
            shift
            ;;
        --packages-only)
            PACKAGES_ONLY=true
            shift
            ;;
        --all)
            ALL_MANAGERS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [MANAGERS]"
            echo ""
            echo "OPTIONS:"
            echo "  --dry-run            Show what would be updated without making changes"
            echo "  --force              Skip confirmation prompts"
            echo "  --manager-only       Update only package managers themselves"
            echo "  --packages-only      Update only installed packages/plugins/tools"
            echo "  --all                Update all package managers"
            echo ""
            echo "MANAGERS (can specify multiple):"
            echo "  --homebrew, --brew   Update only Homebrew"
            echo "  --zinit              Update only zinit"
            echo "  --mise               Update only mise"
            echo ""
            echo "EXAMPLES:"
            echo "  $0                   Select package manager and update scope"
            echo "  $0 --all             Update all package managers"
            echo "  $0 --homebrew        Update only Homebrew"
            echo "  $0 --zinit --mise    Update only zinit and mise"
            echo "  $0 --dry-run --brew  Preview Homebrew updates"
            exit 0
            ;;
        homebrew|brew)
            SELECTED_MANAGERS="$SELECTED_MANAGERS homebrew"
            shift
            ;;
        zinit)
            SELECTED_MANAGERS="$SELECTED_MANAGERS zinit"
            shift
            ;;
        mise)
            SELECTED_MANAGERS="$SELECTED_MANAGERS mise"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If --all is specified or specific managers selected, use those
if [ "$ALL_MANAGERS" = true ] && [ -z "$SELECTED_MANAGERS" ]; then
    SELECTED_MANAGERS="homebrew zinit mise"
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Log function with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if input is 'q' for cancel
is_cancel_input() {
    local input="$1"
    if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
        return 0
    fi
    return 1
}

# Enhanced read function with better terminal support
read_with_editing() {
    local prompt="$1"
    local result

    # Enable readline editing if available (bash)
    if [ -n "$BASH_VERSION" ]; then
        read -e -p "$prompt" result
    else
        # For other shells, use basic read but ensure raw mode
        printf "%s" "$prompt"
        read -r result
    fi

    echo "$result"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_commands=""
    
    if ! command_exists brew; then
        missing_commands="$missing_commands homebrew"
    fi
    
    # Check if zinit directory exists (zinit is a zsh function, not a command)
    if [ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/bin" ]; then
        missing_commands="$missing_commands zinit"
    fi
    
    if ! command_exists mise; then
        missing_commands="$missing_commands mise"
    fi
    
    if [ -n "$missing_commands" ]; then
        log_error "Missing required commands:$missing_commands"
        log_info "Please install missing package managers before running this script"
        return 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_error "No internet connection detected"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

# Update Homebrew
update_homebrew() {
    log "🍺 Updating Homebrew..."

    if [ "$DRY_RUN" = true ]; then
        if [ "$MANAGER_ONLY" = true ]; then
            echo "  Would run: brew update"
        elif [ "$PACKAGES_ONLY" = true ]; then
            echo "  Would run: brew upgrade && brew cleanup"
        else
            echo "  Would run: brew update && brew upgrade && brew cleanup"
        fi
        return 0
    fi

    log_with_timestamp "Starting Homebrew update"

    # Update Homebrew itself (formulae)
    if [ "$PACKAGES_ONLY" = false ]; then
        if brew update; then
            log_success "Homebrew formulae updated"
        else
            log_error "Failed to update Homebrew formulae"
            return 1
        fi
    fi

    # Upgrade installed packages
    if [ "$MANAGER_ONLY" = false ]; then
        if brew upgrade; then
            log_success "Homebrew packages upgraded"
        else
            log_error "Failed to upgrade Homebrew packages"
            return 1
        fi

        if brew cleanup; then
            log_success "Homebrew cleanup completed"
        else
            log_warning "Homebrew cleanup had issues (non-fatal)"
        fi
    fi

    log_with_timestamp "Homebrew update completed"
    return 0
}

# Update zinit
update_zinit() {
    log "⚡ Updating zinit..."

    local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/bin"

    if [ "$DRY_RUN" = true ]; then
        if [ "$MANAGER_ONLY" = true ]; then
            echo "  Would run: git -C \"$zinit_dir\" pull"
        elif [ "$PACKAGES_ONLY" = true ]; then
            echo "  Would run: zsh -c 'zinit update --all'"
        else
            echo "  Would run: git -C \"$zinit_dir\" pull && zsh -c 'zinit update --all'"
        fi
        return 0
    fi

    log_with_timestamp "Starting zinit update"

    # Update zinit itself using git pull (consistent with setup-zinit.sh)
    if [ "$PACKAGES_ONLY" = false ]; then
        if git -C "$zinit_dir" pull; then
            log_success "zinit updated via git pull"
        else
            log_error "Failed to update zinit"
            return 1
        fi
    fi

    # Update all plugins
    if [ "$MANAGER_ONLY" = false ]; then
        if zsh -c 'source "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/bin/zinit.zsh" && zinit update --all'; then
            log_success "All zinit plugins updated"
        else
            log_error "Failed to update zinit plugins"
            return 1
        fi
    fi

    log_with_timestamp "zinit update completed"
    return 0
}

# Update mise
update_mise() {
    log "🔧 Updating mise..."

    if [ "$DRY_RUN" = true ]; then
        if [ "$MANAGER_ONLY" = true ]; then
            echo "  Would run: brew upgrade mise"
        elif [ "$PACKAGES_ONLY" = true ]; then
            echo "  Would run: mise upgrade"
        else
            echo "  Would run: brew upgrade mise && mise upgrade"
        fi
        return 0
    fi

    log_with_timestamp "Starting mise update"

    # Update mise itself via homebrew
    if [ "$MANAGER_ONLY" = false ]; then
        if brew upgrade mise; then
            log_success "mise updated"
        else
            log_error "Failed to update mise"
            return 1
        fi
    fi

    # Upgrade all tools
    if [ "$MANAGER_ONLY" = false ]; then
        if mise upgrade; then
            log_success "All mise tools upgraded"
        else
            log_warning "Some mise tools may have failed to upgrade (check manually)"
        fi
    fi

    log_with_timestamp "mise update completed"
    return 0
}

# Main update function
run_updates() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    log_with_timestamp "=== System update started ==="
    
    local failed_updates=""
    
    # Update selected package managers
    for manager in $SELECTED_MANAGERS; do
        case $manager in
            homebrew)
                if ! update_homebrew; then
                    failed_updates="$failed_updates homebrew"
                fi
                ;;
            zinit)
                if ! update_zinit; then
                    failed_updates="$failed_updates zinit"
                fi
                ;;
            mise)
                if ! update_mise; then
                    failed_updates="$failed_updates mise"
                fi
                ;;
        esac
    done
    
    # Report results
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    log_with_timestamp "=== System update completed ==="
    
    if [ -z "$failed_updates" ]; then
        log_success "All package managers updated successfully! 🎉"
        log_info "Started: $start_time"
        log_info "Finished: $end_time"
        log_info "Log saved to: $LOG_FILE"
        return 0
    else
        log_error "Some updates failed:$failed_updates"
        log_info "Check the log file for details: $LOG_FILE"
        return 1
    fi
}

# Main execution
main() {
    echo "🚀 System Package Update Script"
    echo "================================"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # If no managers selected and not --all, show package manager selection first
    if [ -z "$SELECTED_MANAGERS" ] && [ "$ALL_MANAGERS" = false ]; then
        echo ""
        echo "Which package managers would you like to update?"
        echo "[1] All (homebrew, zinit, mise)"
        echo "[2] Homebrew only"
        echo "[3] zinit only"
        echo "[4] mise only"
        echo "[5] Custom selection"
        echo ""
        manager_choice=$(read_with_editing "Choose [1/2/3/4/5] (q to cancel): ")
        if is_cancel_input "$manager_choice"; then
            log_info "Cancelled by user"
            exit 0
        fi
        case "$manager_choice" in
            1|"")
                SELECTED_MANAGERS="homebrew zinit mise"
                ;;
            2)
                SELECTED_MANAGERS="homebrew"
                ;;
            3)
                SELECTED_MANAGERS="zinit"
                ;;
            4)
                SELECTED_MANAGERS="mise"
                ;;
            5)
                echo ""
                echo "Select package managers (space-separated):"
                echo "Available: homebrew zinit mise"
                SELECTED_MANAGERS=$(read_with_editing "Enter your choice (q to cancel): ")
                if is_cancel_input "$SELECTED_MANAGERS"; then
                    log_info "Cancelled by user"
                    exit 0
                fi
                ;;
            *)
                log_info "Invalid choice. Cancelled by user"
                exit 0
                ;;
        esac
    fi

    # Confirmation prompt (unless --force)
    if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
        # If no specific update mode is selected, ask user to choose
        if [ "$MANAGER_ONLY" = false ] && [ "$PACKAGES_ONLY" = false ]; then
            echo ""
            echo "What would you like to update?"
            echo "[1] Both package managers and packages/plugins/tools (default)"
            echo "[2] Package managers only (brew update, zinit git pull, mise upgrade)"
            echo "[3] Packages/plugins/tools only (brew upgrade, zinit update --all, mise upgrade)"
            echo ""
            choice=$(read_with_editing "Choose [1/2/3] (q to cancel): ")
            if is_cancel_input "$choice"; then
                log_info "Cancelled by user"
                exit 0
            fi
            case "$choice" in
                1|"")
                    # Default - update both
                    ;;
                2)
                    MANAGER_ONLY=true
                    ;;
                3)
                    PACKAGES_ONLY=true
                    ;;
                *)
                    log_info "Invalid choice. Cancelled by user"
                    exit 0
                    ;;
            esac
        fi

        echo ""
        echo "This will update:"
        for manager in $SELECTED_MANAGERS; do
            case $manager in
                homebrew)
                    if [ "$MANAGER_ONLY" = true ]; then
                        echo "  • Homebrew (formulas only)"
                    elif [ "$PACKAGES_ONLY" = true ]; then
                        echo "  • Homebrew (packages only)"
                    else
                        echo "  • Homebrew (formulas and packages)"
                    fi
                    ;;
                zinit)
                    if [ "$MANAGER_ONLY" = true ]; then
                        echo "  • zinit (git pull update only)"
                    elif [ "$PACKAGES_ONLY" = true ]; then
                        echo "  • zinit (plugins only)"
                    else
                        echo "  • zinit (git pull update and all plugins)"
                    fi
                    ;;
                mise)
                    if [ "$MANAGER_ONLY" = true ]; then
                        echo "  • mise (update only)"
                    elif [ "$PACKAGES_ONLY" = true ]; then
                        echo "  • mise (tools only)"
                    else
                        echo "  • mise (update and all tools)"
                    fi
                    ;;
            esac
        done
        echo ""
        response=$(read_with_editing "Continue? [y/N] (q to cancel): ")
        if is_cancel_input "$response"; then
            log_info "Cancelled by user"
            exit 0
        fi
        case "$response" in
            [yY][eE][sS]|[yY])
                ;;
            *)
                log_info "Update cancelled by user"
                exit 0
                ;;
        esac
    fi
    
    # Run updates
    if run_updates; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"