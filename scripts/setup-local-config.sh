#!/bin/bash
# Use bash for better readline support (backspace, arrow keys, etc.)

echo "⚙️ Setting up local configuration..."

LOCAL_CONFIG="$HOME/.config/zsh/.zshrc.local"
# Try symlinked template first (after setup-links), then fallback to repo location
TEMPLATE_CONFIG="$HOME/templates/zsh/.zshrc.local.template"
if [ ! -f "$TEMPLATE_CONFIG" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DOTFILES_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
    TEMPLATE_CONFIG="$DOTFILES_HOME/packages/templates/templates/zsh/.zshrc.local.template"
fi

# Skip if local config already exists
if [ -f "$LOCAL_CONFIG" ]; then
    echo "✓ Local configuration already exists at $LOCAL_CONFIG"
    exit 0
fi

# Create config directory if it doesn't exist
mkdir -p "$(dirname "$LOCAL_CONFIG")"

# Interactive email setup
setup_interactive_config() {
    echo ""
    echo "📧 Setting up email configuration"
    echo "This will be used for Git commits, Google Drive screenshots, and other services"
    echo ""

    # Enable readline functionality
    set -o emacs # Enable emacs-style line editing (includes backspace)

    # Get primary email
    printf "Enter your primary email address: "
    read -r -e -e PRIMARY_EMAIL

    if [ -z "$PRIMARY_EMAIL" ]; then
        echo "❌ Email address is required"
        return 1
    fi

    # Auto-detect Google Drive email
    GOOGLE_DRIVE_DIR="$HOME/Library/CloudStorage"
    DETECTED_GOOGLE_DRIVE_EMAIL=""

    if [ -d "$GOOGLE_DRIVE_DIR" ] && ls "$GOOGLE_DRIVE_DIR"/GoogleDrive-* >/dev/null 2>&1; then
        DETECTED_GOOGLE_DRIVE_EMAIL=$(basename "$(ls -d "$GOOGLE_DRIVE_DIR"/GoogleDrive-* 2>/dev/null | head -1)" | sed 's/GoogleDrive-//' 2>/dev/null)
    fi

    # Ask about Google Drive email
    GOOGLE_DRIVE_EMAIL=""
    if [ -n "$DETECTED_GOOGLE_DRIVE_EMAIL" ]; then
        echo ""
        echo "📁 Detected Google Drive email: $DETECTED_GOOGLE_DRIVE_EMAIL"
        printf "Is this the same as your primary email? (y/n) [y]: "
        read -r -e -e use_same_google

        case "$use_same_google" in
        n | N | no | No | NO)
            printf "Enter your Google Drive email address: "
            read -r -e -e GOOGLE_DRIVE_EMAIL
            if [ -z "$GOOGLE_DRIVE_EMAIL" ]; then
                GOOGLE_DRIVE_EMAIL="$DETECTED_GOOGLE_DRIVE_EMAIL"
            fi
            ;;
        *)
            GOOGLE_DRIVE_EMAIL="$PRIMARY_EMAIL"
            ;;
        esac
    else
        echo ""
        printf "Do you use Google Drive? (y/n) [n]: "
        read -r -e use_google_drive

        case "$use_google_drive" in
        y | Y | yes | Yes | YES)
            printf "Is your Google Drive email the same as your primary email? (y/n) [y]: "
            read -r -e same_google_email

            case "$same_google_email" in
            n | N | no | No | NO)
                printf "Enter your Google Drive email address: "
                read -r -e GOOGLE_DRIVE_EMAIL
                ;;
            *)
                GOOGLE_DRIVE_EMAIL="$PRIMARY_EMAIL"
                ;;
            esac
            ;;
        esac
    fi

    # Ask about GitHub email
    GITHUB_EMAIL=""
    echo ""
    printf "Is your GitHub email the same as your primary email? (y/n) [y]: "
    read -r -e same_github_email

    case "$same_github_email" in
    n | N | no | No | NO)
        printf "Enter your GitHub email address: "
        read -r -e GITHUB_EMAIL
        if [ -z "$GITHUB_EMAIL" ]; then
            GITHUB_EMAIL="$PRIMARY_EMAIL"
        fi
        ;;
    *)
        GITHUB_EMAIL="$PRIMARY_EMAIL"
        ;;
    esac

    # Create configuration file
    cat >"$LOCAL_CONFIG" <<EOF
# Local configuration (interactively configured)
# This file contains local settings that should not be committed to git

# Primary email address
export EMAIL="$PRIMARY_EMAIL"

# Git configuration (uses primary email)
export GIT_AUTHOR_EMAIL="\$EMAIL"
export GIT_COMMITTER_EMAIL="\$EMAIL"
EOF

    # Add Google Drive email (always include if configured)
    if [ -n "$GOOGLE_DRIVE_EMAIL" ]; then
        if [ "$GOOGLE_DRIVE_EMAIL" = "$PRIMARY_EMAIL" ]; then
            cat >>"$LOCAL_CONFIG" <<EOF

# Google Drive email (uses primary email)
export GOOGLE_DRIVE_EMAIL="\$EMAIL"
EOF
        else
            cat >>"$LOCAL_CONFIG" <<EOF

# Google Drive email (for screenshot paths)
export GOOGLE_DRIVE_EMAIL="$GOOGLE_DRIVE_EMAIL"
EOF
        fi
    fi

    # Add GitHub email if different from primary
    if [ -n "$GITHUB_EMAIL" ] && [ "$GITHUB_EMAIL" != "$PRIMARY_EMAIL" ]; then
        cat >>"$LOCAL_CONFIG" <<EOF

# GitHub email (for GitHub CLI and other GitHub tools)
export GITHUB_EMAIL="$GITHUB_EMAIL"
EOF
    fi

    cat >>"$LOCAL_CONFIG" <<EOF

# Add your custom local settings below
# export CUSTOM_VAR="value"
EOF

    echo ""
    echo "✓ Created $LOCAL_CONFIG with the following configuration:"
    echo "  Primary email: $PRIMARY_EMAIL"
    if [ -n "$GOOGLE_DRIVE_EMAIL" ]; then
        echo "  Google Drive email: $GOOGLE_DRIVE_EMAIL"
    fi
    if [ -n "$GITHUB_EMAIL" ]; then
        echo "  GitHub email: $GITHUB_EMAIL"
    fi
}

# Check if running in non-interactive mode
if [ -t 0 ]; then
    # Interactive mode
    setup_interactive_config
    if [ $? -ne 0 ]; then
        echo "❌ Failed to set up configuration"
        exit 1
    fi
else
    # Non-interactive mode - create minimal config
    echo "⚠️  Running in non-interactive mode, creating minimal configuration"
    if [ -f "$TEMPLATE_CONFIG" ]; then
        cp "$TEMPLATE_CONFIG" "$LOCAL_CONFIG"
    else
        cat >"$LOCAL_CONFIG" <<EOF
# Local configuration
# This file contains local settings that should not be committed to git

# Email (set manually if needed)
# export EMAIL="your-email@gmail.com"
# export GIT_AUTHOR_EMAIL="\$EMAIL"
# export GIT_COMMITTER_EMAIL="\$EMAIL"

# Add your custom local settings below
# export CUSTOM_VAR="value"
EOF
    fi
    echo "✓ Created $LOCAL_CONFIG from template"
fi

echo ""
echo "📝 To complete the setup, reload your shell configuration:"
echo "   source ~/.config/zsh/.zshrc"
echo ""
echo "📁 Local config file location: $LOCAL_CONFIG"
