# ==========================================
#  非同期処理の fd リーク対策
# ==========================================
#
# 症状（2026-08-11 に遭遇。以後シェルが何も受け付けなくなる）:
#   _zsh_autosuggest_async_request:45: 255: too many open files
#   _zsh_autosuggest_async_request:31: write error: bad file descriptor
#   .autocomplete:async:wait:sysopen:2: can't open file /dev/fd/255
#   -fast-highlight-main-type:25: 1: too many open files
#
# 「上限が低い」と「fd を閉じ損ねる」の掛け算だった。
#
# 主犯だった zsh-autocomplete は 2026-08-12 に削除した（04-plugins.zsh に経緯）。
# 本体を文字列置換で patch していた節はこのファイルから取り除いてある。
# 残しているのは上限の引き上げと、zsh-autosuggestions 側の取りこぼしの2つ。

# ------------------------------------------------------------------
#  1. soft limit を上げる
# ------------------------------------------------------------------
# macOS の launchd は soft limit を 256 で渡す。
#   $ launchctl limit maxfiles
#     maxfiles  256  unlimited
# GUI から起動した Ghostty はこれを引き継ぐので、対話シェルの fd 上限も 256。
# エラーに出る「255」「/dev/fd/255」はその最後の1本にあたる。
# hard limit は unlimited なので soft はいくらでも上げられる。
#
# 256 は余裕が無さすぎる。塞ぎ漏れがあっても実用上困らない所まで上げる。
# 既に高いシェル（Claude Code 経由など）では下げない。
#
# 引き上げる前の値を控えておく。端末から渡された soft limit が実際いくつなのかは
# 上げてしまうと分からなくなるため。実測値:
#   Ghostty から直接    256（launchd 既定）
#   tmux サーバ経由    8192（サーバを起動したシェルが既に上げていた）
typeset -g FD_LIMIT_INHERITED=$(ulimit -n)

if [[ $FD_LIMIT_INHERITED == <-> ]] && (( FD_LIMIT_INHERITED < 8192 )); then
    ulimit -n 8192
fi

# ------------------------------------------------------------------
#  2. zsh-autosuggestions の取りこぼしを塞ぐ
# ------------------------------------------------------------------
# _zsh_autosuggest_async_response（zsh-autosuggestions.zsh:820-834）は
#   [[ -z "$2" || "$2" == "hup" ]]
# の時だけ fd を閉じる。zle -F のハンドラは "err" や "nval" でも呼ばれ、
# その経路では閉じないまま _ZSH_AUTOSUGGEST_ASYNC_FD を空にするので、
# 次の要求の取り消し処理からも辿れなくなる。
#
# こちらは「fd が既に壊れた後」に通る経路なので、主犯というより二次被害の側。
# 二重 close を避けるため、漏れる分岐だけを補う。
if (( $+functions[_zsh_autosuggest_async_response] )); then
    functions[__orig_zsh_autosuggest_async_response]=$functions[_zsh_autosuggest_async_response]
    _zsh_autosuggest_async_response() {
        __orig_zsh_autosuggest_async_response "$@"
        [[ -n $2 && $2 != hup ]] && { exec {1}<&- } 2>/dev/null
        return 0
    }
fi

