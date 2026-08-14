#!/bin/sh

###########################################################
# zsh の履歴を 1Password へ退避・復元する
###########################################################
# Usage:
#   ./bin/history-vault.sh save      履歴を 1Password へ保存（既存があれば更新）
#   ./bin/history-vault.sh restore   1Password から履歴を取り出す
#   ./bin/history-vault.sh diff      手元と 1Password の差分を見る
#
# なぜ 1Password なのか:
#   このリポジトリは公開されているので履歴を平文で置けない。暗号化して
#   公開リポジトリに入れる手もあるが、暗号文が永久に公開の場へ残るため
#   （harvest now, decrypt later）採らなかった。1Password は SSH 鍵と
#   コミット署名で既に必須の依存なので、新しく増える依存がゼロになる。
#
# 前提:
#   履歴そのものに秘密を入れない。rc.d/02-functions.zsh の zshaddhistory が
#   _hist_secret_re に一致する行を記録しないようにしてある。ここでの暗号化は
#   あくまで保険で、一次防御は「書かないこと」。

set -eu

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_DIR/scripts/utils.sh"

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HISTFILE="${HISTFILE:-$XDG_STATE_HOME/zsh/history}"
ITEM_TITLE="zsh-history"
# 個人アカウントの既定の vault 名。組織アカウントや名前を変えている場合は
# HISTORY_VAULT で上書きする
VAULT="${HISTORY_VAULT:-Personal}"

require_op() {
    if ! command -v op >/dev/null 2>&1; then
        log_error "1Password CLI (op) が見つかりません"
        exit 1
    fi
    if ! op account list >/dev/null 2>&1; then
        log_error "1Password にサインインしていません: eval \$(op signin)"
        exit 1
    fi
    if ! op vault get "$VAULT" >/dev/null 2>&1; then
        log_error "vault \"$VAULT\" が見つかりません。HISTORY_VAULT で指定してください"
        log_info "このアカウントの vault:"
        op vault list >&2
        exit 1
    fi
}

item_exists() {
    op item get "$ITEM_TITLE" --vault "$VAULT" >/dev/null 2>&1
}

cmd_save() {
    require_op
    if [ ! -f "$HISTFILE" ]; then
        log_error "履歴ファイルがありません: $HISTFILE"
        exit 1
    fi

    # 保存する前に秘密が混じっていないか見る。zshaddhistory を入れる前に
    # 記録された行が残っている可能性があるため、退避のたびに確認する。
    #
    # 定義は rc.d/02-functions.zsh の _hist_secret_re と同じものを使う。
    # 片方だけ緩いと「書き込み時は通ったのに退避時に止まる」という食い違いが
    # 起きる（実際、以前はここだけ -i と裸の PRIVATE KEY を使っていて、
    # 秘密を含まない grep コマンドを誤検知した）。変更する時は両方を直す
    secret_re='(--?(password|passwd|token|secret|api[-_]?key)|Bearer |PRIVATE KEY|[A-Za-z_]*(KEY|TOKEN|SECRET|PASSWORD)=)'
    if grep -qE "$secret_re" "$HISTFILE"; then
        log_warn "秘密らしい行が含まれています。確認してから再実行してください:"
        grep -nE "$secret_re" "$HISTFILE" >&2
        exit 1
    fi

    lines="$(wc -l < "$HISTFILE" | tr -d ' ')"
    if item_exists; then
        # 手元が保存済みより短い時は止める。新しいマシンで restore する前に
        # 誤って save すると、育てた履歴が数行に置き換わる。
        # 1Password 側にドキュメントの版は残るが、気づかなければ意味がない
        stored_tmp="$(mktemp)"
        op document get "$ITEM_TITLE" --vault "$VAULT" --out-file "$stored_tmp" --force >/dev/null
        stored_lines="$(wc -l < "$stored_tmp" | tr -d ' ')"
        rm -f "$stored_tmp"

        if [ "$lines" -lt "$stored_lines" ] && [ "$FORCE" -eq 0 ]; then
            log_warn "手元の方が短いので中断しました（手元 $lines 行 / 保存済み $stored_lines 行）"
            log_info "先に restore するか、意図した縮小なら --force を付けてください"
            exit 1
        fi

        op document edit "$ITEM_TITLE" "$HISTFILE" --vault "$VAULT" >/dev/null
        log_success "更新しました（$lines 行）"
    else
        op document create "$HISTFILE" \
            --title "$ITEM_TITLE" --vault "$VAULT" --file-name "zsh-history" >/dev/null
        log_success "作成しました（$lines 行）"
    fi
}

cmd_restore() {
    require_op
    if ! item_exists; then
        log_error "1Password に $ITEM_TITLE がありません"
        exit 1
    fi

    mkdir -p "$(dirname "$HISTFILE")"

    # 手元の履歴は消さずに退避する。マージは行単位の単純な結合では
    # EXTENDED_HISTORY の複数行エントリを壊すため、意図的に自動化しない
    if [ -f "$HISTFILE" ]; then
        backup="$HISTFILE.$(date +%Y%m%d%H%M%S).bak"
        cp "$HISTFILE" "$backup"
        log_info "手元の履歴を退避しました: $backup"
    fi

    op document get "$ITEM_TITLE" --vault "$VAULT" --out-file "$HISTFILE" --force >/dev/null
    chmod 600 "$HISTFILE"
    log_success "復元しました（$(wc -l < "$HISTFILE" | tr -d ' ') 行）"
}

cmd_diff() {
    require_op
    if ! item_exists; then
        log_error "1Password に $ITEM_TITLE がありません"
        exit 1
    fi

    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    op document get "$ITEM_TITLE" --vault "$VAULT" --out-file "$tmp" --force >/dev/null

    if diff -q "$tmp" "$HISTFILE" >/dev/null 2>&1; then
        log_success "同じです"
    else
        printf '  1Password: %s 行\n' "$(wc -l < "$tmp" | tr -d ' ')"
        printf '  手元:      %s 行\n' "$(wc -l < "$HISTFILE" | tr -d ' ')"
        diff "$tmp" "$HISTFILE" | head -20
    fi
}

FORCE=0
sub=""
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *)       [ -z "$sub" ] && sub="$arg" ;;
    esac
done

case "$sub" in
    save)    cmd_save ;;
    restore) cmd_restore ;;
    diff)    cmd_diff ;;
    *)
        printf 'Usage: %s {save|restore|diff} [--force]\n' "$(basename "$0")" >&2
        printf '  save     履歴を 1Password へ保存（既存があれば更新）\n' >&2
        printf '  restore  1Password から取り出す（手元は .bak へ退避）\n' >&2
        printf '  diff     手元と 1Password の差分を見る\n' >&2
        printf '  --force  save で手元の方が短くても上書きする\n' >&2
        exit 1
        ;;
esac
