#!/usr/bin/env bash
set -e

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Get the real path of the script (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=./scripts/common.sh
source "$SCRIPT_DIR/../scripts/common.sh"
source "$SCRIPT_DIR/../scripts/utils.sh"

DOTFILES_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
STOW_PACKAGES_PATH="$DOTFILES_HOME/packages"

###########################################################
# Options
###########################################################
unlink_packages=()
for i in "$@"; do
    case "$i" in
    -u | --unlink)
        shift
        while [[ "$1" != -* && ! -z "$1" ]]; do
            if [[ "$1" != "-u" && "$1" != "--unlink" ]]; then
                unlink_packages+=("$1")
            fi
            shift
        done
        ;;
    -uall | --unlink-all)
        unlink_all=1
        shift
        ;;
    *) ;;
    esac
done

###########################################################
# Clean broken symlinks
###########################################################
clean_broken_symlinks() {
    log 'Cleaning broken symlinks...'

    # Find broken symlinks that point to dotfiles packages
    broken_links=()

    # Search in home directory (excluding .config to avoid duplicates)
    while IFS= read -r -d '' link; do
        if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
            target=$(readlink "$link")
            # Check if the symlink points to our dotfiles packages or scripts
            if [[ "$target" == *"dotfiles/packages/"* ]] || [[ "$target" == *"dotfiles/scripts/"* ]]; then
                broken_links+=("$link")
            fi
        fi
    done < <(find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null)

    # Search in ~/.config
    while IFS= read -r -d '' link; do
        if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
            target=$(readlink "$link")
            # Check if the symlink points to our dotfiles packages
            if [[ "$target" == *"dotfiles/packages/"* ]]; then
                broken_links+=("$link")
            fi
        fi
    done < <(find "$HOME/.config" -type l -print0 2>/dev/null)

    # Search in ~/.local/bin for broken script links
    if [[ -d "$HOME/.local/bin" ]]; then
        while IFS= read -r -d '' link; do
            if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
                target=$(readlink "$link")
                # Check if the symlink points to our dotfiles scripts
                if [[ "$target" == *"dotfiles/scripts/"* ]]; then
                    broken_links+=("$link")
                fi
            fi
        done < <(find "$HOME/.local/bin" -type l -print0 2>/dev/null)
    fi

    if [ ${#broken_links[@]} -gt 0 ]; then
        log "📌 Found ${#broken_links[@]} broken symlinks, removing them..."
        for link in "${broken_links[@]}"; do
            log "📌 Removing broken symlink: $link"
            rm "$link"
        done
        log 'Broken symlinks removed successfully.'
    fi
}

###########################################################
# Unlink
###########################################################
if [ ${#unlink_packages[@]} -gt 0 ]; then
    for package in "${unlink_packages[@]}"; do
        log "📌 Unlinking packages: $package"
        stow -vD -d "$STOW_PACKAGES_PATH" -t ~ "$package"
    done
    exit
fi

if [ "$unlink_all" = 1 ]; then
    # .gitmodules が無いリポジトリでも -uall が動くようガード
    submodules="__no_submodules__"
    if [ -f "$DOTFILES_HOME/.gitmodules" ]; then
        submodules=$(awk '/path/ {print $3}' "$DOTFILES_HOME/.gitmodules" | sed 's|.*/||')
    fi
    full_paths="$(fd --hidden --no-ignore -t f -H -I -E "$submodules" -E "zsh" . "$STOW_PACKAGES_PATH")"

    # Extract unique package names from paths
    unlink_packages=()
    while IFS= read -r package_name; do
        [[ " ${unlink_packages[*]} " =~ " ${package_name} " ]] || unlink_packages+=("$package_name")
    done < <(echo "$full_paths" | sed -n 's|.*/packages/\([^/]*\)/.*|\1|p' | sort -u)

    log 'Unlinking all packages...'
    for package in "${unlink_packages[@]}"; do
        stow -vD -d "$STOW_PACKAGES_PATH" -t "$HOME" "$package"
    done
    # -------------------------------------------------------------------------
    log 'Unlinking scripts...'

    unlink_script_paths=($(find "${DOTFILES_HOME}/bin" -type f -exec basename {} \;))
    for script_name in "${unlink_script_paths[@]}"; do
        rm "$HOME/.local/bin/$script_name"
    done

    exit
fi

# Clean broken symlinks before linking
clean_broken_symlinks

##########################################################
# link
##########################################################
### mkdir
make_dir=(
    "$XDG_CONFIG_HOME"
    "$XDG_STATE_HOME"
    "$XDG_CACHE_HOME"
    "$XDG_CONFIG_HOME/zsh"
    "$XDG_CACHE_HOME/zsh"
    "$XDG_STATE_HOME/zsh" # HISTFILEの置き場。無いとzshが履歴を保存できない
    # VSCode未起動のマシンでstowがCodeフォルダごとsymlink化（folding）し、
    # キャッシュ類がリポジトリ内に書き込まれる事故を防ぐ
    "$HOME/Library/Application Support/Code/User"
    # 同上：Claude Code未起動のマシンで履歴・キャッシュがリポジトリに入るのを防ぐ
    "$HOME/.claude"
    # 同上：cheatsごとfoldingされると navi repo add のクローンがリポジトリ内に降ってくる
    "$XDG_DATA_HOME/navi/cheats"
)
for dir in "${make_dir[@]}"; do
    ensure_dir "$dir"
done

ensure_dir "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# GnuPG（GNUPGHOMEで$XDG_DATA_HOME/gnupgに移設済み）
# 秘密鍵が入りうるためリポジトリでは管理しない。ディレクトリと権限だけ用意する
ensure_dir "${XDG_DATA_HOME:-$HOME/.local/share}/gnupg"
chmod 700 "${XDG_DATA_HOME:-$HOME/.local/share}/gnupg"

### Stow link ###
log 'Linking packages...'
# Use array to handle package names with spaces safely
packages=()
while IFS= read -r -d '' package; do
    packages+=("$(basename "$package")")
done < <(find "$STOW_PACKAGES_PATH" -mindepth 1 -maxdepth 1 -type d -print0)

if [ ${#packages[@]} -gt 0 ]; then
    stow -vd "$STOW_PACKAGES_PATH" -t "$HOME" --ignore="bin" "${packages[@]}"
fi

# -------------------------------------------------------------------------
log 'Linking package scripts...'
ensure_dir "$HOME/.local/bin"

# -------------------------------------------------------------------------
log 'Linking man pages...'
ensure_dir "$HOME/.local/share/man"
if [ -d "$DOTFILES_HOME/man" ]; then
    safe_symlink "$DOTFILES_HOME/man" "$HOME/.local/share/man/dotfiles"
fi
# Link scripts from packages/*/bin/ directories (first level only) safely
for package_dir in "$STOW_PACKAGES_PATH"/*; do
    if [ -d "$package_dir/bin" ]; then
        for script in "$package_dir/bin/"*; do
            if [ -f "$script" ]; then
                script_name="$(basename "$script")"
                safe_symlink "$script" "$HOME/.local/bin/$script_name"
            fi
        done
    fi
done

# -------------------------------------------------------------------------
log 'Linking utility scripts...'
# Link individual scripts from bin/ directory only
for script in "$DOTFILES_HOME/bin/"*; do
    if [ -f "$script" ]; then
        script_name="$(basename "$script")"
        safe_symlink "$script" "$HOME/.local/bin/$script_name"
    fi
done

# Nix本体の導入とnix-darwinの再適用を個別に実行できるようPATHへ通す
if [ -f "$DOTFILES_HOME/scripts/setup-nix.sh" ]; then
    safe_symlink "$DOTFILES_HOME/scripts/setup-nix.sh" "$HOME/.local/bin/setup-nix.sh"
fi

# -------------------------------------------------------------------------
