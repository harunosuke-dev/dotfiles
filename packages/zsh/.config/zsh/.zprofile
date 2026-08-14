#########################################################################
# ZSH CONFIGURATION - LOGIN SHELL (PATH / ログイン時セットアップ)
#########################################################################
#
# ログインシェルで一度だけ実行される（macOS では新規タブ/ウィンドウも毎回ログイン扱い）。
# PATH の確定はここに集約する。下で path_helper を自分で呼んだ "後" に走るため、
# ここで前方に置いたユーザーディレクトリが確実に優先される。
#
# 対話専用の設定（キーバインド・補完・プロンプト・setopt 等）は .zshrc へ。
# スクリプトからも要る env（XDG / ZDOTDIR / 各ツールの位置）は .zshenv へ。
#########################################################################

### PATH Configuration ###
typeset -U path

# macOS 純正の /etc/zprofile はここで path_helper を呼んでいたが、nix-darwin が
# /etc/zprofile を置き換えた際にその呼び出しごと消えた。結果 /etc/paths.d/* が
# PATH に入らなくなるため、ここで呼び戻す。
# 非 macOS や path_helper の無い環境では -x で素通りする。
if [ -x /usr/libexec/path_helper ]; then
  eval "$(/usr/libexec/path_helper -s)"
fi

path=(
  "$HOME/.local/bin"(N-/)       # User binaries (highest priority)
  "$NPM_DATA_DIR/bin"(N-/)      # npm install -g の実行ファイル置き場
  # Nix。path_helper は /etc/paths と /etc/paths.d/* を PATH の先頭へ積み直すので、
  # 放っておくと nix 由来のパスが最後尾へ落ちる。そうなると bash が nix の 5.x では
  # なく Apple の 3.2 に解決され、#!/usr/bin/env bash なスクリプトが壊れる。
  # 実際に奪われるのは bash / sh / zsh の 3 つだけだが、bash の差が大きいので前へ戻す。
  "$HOME/.nix-profile/bin"(N-/)
  "/run/current-system/sw/bin"(N-/)
  "/nix/var/nix/profiles/default/bin"(N-/)
  "$path[@]"                    # Existing PATH (path_helper 由来のシステムパス等)
  "/opt/homebrew/bin"(N-/)      # Homebrew binaries
  "/opt/homebrew/sbin"(N-/)     # Homebrew system binaries
  "/Library/Apple/usr/bin"(N-/) # Apple developer tools
)

