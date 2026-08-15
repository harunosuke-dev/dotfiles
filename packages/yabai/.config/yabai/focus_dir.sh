#!/bin/bash
# フォーカスを移す。引数は west / east / north / south。
#
# レイアウトによって意味を変える。
#
#   bsp（タイル）          画面上の位置関係で移動する
#   stack / 全てフロート   位置を無視して全ウィンドウをループ巡回する
#
# stack や alt + shift - c のフロート中は、全ウィンドウが同じ場所に
# 重なるため「西」「北」に相当するウィンドウが存在しない。yabai の
# --focus west / north はいずれも失敗するので、順送りに倒す。
#
#   h（west） k（north） → 前へ
#   l（east） j（south） → 次へ

set -uo pipefail

readonly CYCLE="$HOME/.config/yabai/focus_cycle.sh"
dir="${1:-east}"

layout=$(yabai -m query --spaces --space 2>/dev/null | jq -r '.type')
floating=$(yabai -m query --windows --window 2>/dev/null | jq -r '."is-floating" // false')

if [ "$layout" = "bsp" ] && [ "$floating" = "false" ]; then
  # bsp の中に積まれたウィンドウ（stack）がある場合は、まずそちらを送る
  case "$dir" in
    north) yabai -m window --focus stack.prev 2>/dev/null && exit 0 ;;
    south) yabai -m window --focus stack.next 2>/dev/null && exit 0 ;;
  esac
  yabai -m window --focus "$dir" 2>/dev/null && exit 0
fi

case "$dir" in
  west | north) exec "$CYCLE" prev ;;
  *)            exec "$CYCLE" next ;;
esac
