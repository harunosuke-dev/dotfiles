#!/bin/bash
# 現在のスペースにある全ウィンドウをフロート化して中央に揃える。
# もう一度実行するとタイルに戻す。
#
# 個別のウィンドウだけをフロートさせる toggle_float_focus.sh と違い、
# スペース全体を「重ねて中央に置く」状態にする。切り替えは alt + j / k で行う
# （yabai の --focus next / prev はフロート中のウィンドウも巡回する）。

set -uo pipefail

readonly GRID='10:10:1:1:8:8'  # 10x10 の格子で 1,1 から 8x8 ぶん = 中央 80%

# 最小化・全スペース常駐のウィンドウは対象外にする
windows=$(yabai -m query --windows --space \
  | jq -c '[.[] | select(."is-minimized" == false and ."is-sticky" == false)]')

if [ -z "$windows" ] || [ "$(echo "$windows" | jq 'length')" -eq 0 ]; then
  exit 0
fi

focused=$(echo "$windows" | jq -r '.[] | select(."has-focus" == true) | .id' | head -1)
tiled=$(echo "$windows" | jq '[.[] | select(."is-floating" == false)] | length')

# フロートしていないウィンドウが1つでも残っていれば「フロート化」に倒す。
# 全てフロート済みのときだけタイルへ戻す
if [ "$tiled" -gt 0 ]; then
  for id in $(echo "$windows" | jq -r '.[] | select(."is-floating" == false) | .id'); do
    yabai -m window "$id" --toggle float
    yabai -m window "$id" --grid "$GRID"
  done
  osascript -e 'tell application "HazeOver" to set enabled to true' 2>/dev/null
else
  for id in $(echo "$windows" | jq -r '.[].id'); do
    yabai -m window "$id" --toggle float
  done
  osascript -e 'tell application "HazeOver" to set enabled to false' 2>/dev/null
fi

# 元のウィンドウにフォーカスを戻す。フロート化の過程で移ることがあるため
if [ -n "$focused" ]; then
  yabai -m window --focus "$focused" 2>/dev/null
fi
