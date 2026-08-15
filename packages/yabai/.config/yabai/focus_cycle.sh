#!/bin/bash
# 現在のスペースのウィンドウを順に巡回する。引数は next または prev。
#
# yabai の --focus next / prev / west / east が対象にするのは bsp 配置の
# ウィンドウ（managed window）だけで、フロート中のものは含まれない。
# toggle_float_space.sh で全ウィンドウをフロート化すると、これらが
# 「could not locate the next managed window」で失敗する。その補完。
#
# skhd 側では stack.next → next → このスクリプト の順に試している。

set -uo pipefail

dir="${1:-next}"

# bash 3.2 には mapfile が無いので単語分割で配列にする（id は数値のみ）
ids=($(yabai -m query --windows --space \
  | jq -r '[.[] | select(."is-minimized" == false)] | sort_by(.id) | .[].id'))

n=${#ids[@]}
[ "$n" -le 1 ] && exit 0

cur=$(yabai -m query --windows --window 2>/dev/null | jq -r '.id')

idx=0
for i in $(seq 0 $((n - 1))); do
  if [ "${ids[$i]}" = "$cur" ]; then
    idx=$i
    break
  fi
done

if [ "$dir" = "prev" ]; then
  target=$(( (idx - 1 + n) % n ))
else
  target=$(( (idx + 1) % n ))
fi

yabai -m window --focus "${ids[$target]}"
