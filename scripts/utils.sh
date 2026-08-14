#!/bin/sh

###########################################################
# Utils
###########################################################
# Enhanced logging functions
log() {
    message="$1"
    echo "$message"
}

log_info() {
    message="$1"
    echo "ℹ️  INFO: $message"
}

log_success() {
    message="$1"
    printf "\033[32m✓\033[0m %s\n" "$message"
}

log_warn() {
    message="$1"
    printf "\033[33m⚠️  WARN: %s\033[0m\n" "$message" >&2
}

log_error() {
    message="$1"
    printf "\033[31m❌ ERROR: %s\033[0m\n" "$message" >&2
}

log_step() {
    step="$1"
    message="$2"
    echo "▶️ STEP $step: $message"
}

is_file() {
    path="$1"
    [ -f "$path" ]
}

is_dir() {
    path="$1"
    [ -d "$path" ]
}

ensure_dir() {
    path="$1"
    if ! is_dir "$path"; then
        mkdir -p "$path"
    fi
}

# Error handling functions
setup_error_handling() {
    set -e
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
}

handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    echo "❌ ERROR: Command failed with exit code $exit_code at line $line_number: $command" >&2
    echo "📍 Script: ${BASH_SOURCE[1]}" >&2
    exit $exit_code
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running on macOS
is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

# Dependency checking functions
check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    log_step "DEP" "Checking dependencies..."
    
    for dep in "${dependencies[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
            log_warn "$dep is not installed"
        else
            log_info "$dep is available"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All dependencies are available"
    return 0
}

# Check macOS Command Line Tools
check_xcode_tools() {
    if ! xcode-select -p >/dev/null 2>&1; then
        log_warn "Command Line Tools not installed"
        log_info "Installing Command Line Tools..."
        xcode-select --install
        log_info "Please complete the installation and re-run this script"
        exit 1
    else
        log_info "Command Line Tools are installed"
    fi
}

# Check internet connectivity
check_internet() {
    if ! ping -c 1 google.com >/dev/null 2>&1 && ! curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; then
        log_error "No internet connection available"
        return 1
    fi
    log_info "Internet connection is available"
    return 0
}

# Backup and restore functions
backup_file() {
    local file="$1"
    local backup_dir="${2:-$XDG_STATE_HOME/dotfiles/backup}"
    
    if [ -f "$file" ] || [ -L "$file" ]; then
        ensure_dir "$backup_dir"
        local backup_name="$(basename "$file").$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up $file to $backup_dir/$backup_name"
        cp "$file" "$backup_dir/$backup_name" 2>/dev/null || {
            log_warn "Failed to backup $file"
            return 1
        }
    fi
    return 0
}

# Safe symlink creation (removes existing file/link first)
safe_symlink() {
    local source="$1"
    local target="$2"
    
    if [ ! -e "$source" ] && [ ! -L "$source" ]; then
        log_error "Source file does not exist: $source"
        return 1
    fi
    
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ]; then
            local current_target
            current_target="$(readlink "$target")"
            if [ "$current_target" = "$source" ]; then
                # Symlink already exists and is correct - no output needed
                return 0
            fi
            log_info "Removing existing symlink: $target"
        else
            backup_file "$target"
            log_info "Removing existing file: $target"
        fi
        rm -f "$target"
    fi
    
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Check if process is running
is_process_running() {
    local process_name="$1"
    pgrep -x "$process_name" >/dev/null 2>&1
}

# List backups
list_backups() {
    local backup_dir="${1:-$XDG_STATE_HOME/dotfiles/backup}"
    
    if [ ! -d "$backup_dir" ]; then
        log_info "No backup directory found at: $backup_dir"
        return 1
    fi
    
    log_info "Backups in $backup_dir:"
    ls -la "$backup_dir" | while read -r line; do
        echo "  $line"
    done
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    local target="${2:-}"
    local backup_dir="${3:-$XDG_STATE_HOME/dotfiles/backup}"
    
    if [ ! -f "$backup_dir/$backup_file" ]; then
        log_error "Backup file not found: $backup_dir/$backup_file"
        return 1
    fi
    
    if [ -z "$target" ]; then
        # Extract original filename from backup name
        target="$HOME/$(echo "$backup_file" | sed 's/\.[0-9]\{8\}_[0-9]\{6\}$//')"
    fi
    
    log_info "Restoring $backup_dir/$backup_file to $target"
    cp "$backup_dir/$backup_file" "$target"
    log_success "Restored: $target"
}

# Clean old backups (keep only latest N backups per file)
clean_old_backups() {
    local backup_dir="${1:-$XDG_STATE_HOME/dotfiles/backup}"
    local keep_count="${2:-5}"
    
    if [ ! -d "$backup_dir" ]; then
        log_info "No backup directory found"
        return 0
    fi
    
    log_info "Cleaning old backups (keeping latest $keep_count per file)..."
    
    # Group backups by original filename
    find "$backup_dir" -name "*.20*_*" | sed 's/\.[0-9]\{8\}_[0-9]\{6\}$//' | sort -u | while read -r base_name; do
        base_file="$(basename "$base_name")"
        # Keep only the latest backups
        ls -t "$backup_dir"/"$base_file".20*_* 2>/dev/null | tail -n +$((keep_count + 1)) | while read -r old_backup; do
            log_info "Removing old backup: $old_backup"
            rm -f "$old_backup"
        done
    done
}
