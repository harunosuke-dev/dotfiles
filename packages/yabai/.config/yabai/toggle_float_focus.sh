#!/bin/bash

WINDOW_ID=$(yabai -m query --windows --window | jq -re '.id')
FLOAT_STATUS=$(yabai -m query --windows --window | jq -re '.["is-floating"]')
if [ "$FLOAT_STATUS" = "false" ]; then
    # ウィンドウをフロート化する場合
    # 現在のフォーカス設定を保存
    CURRENT_FOCUS=$(yabai -m config focus_follows_mouse)
    CURRENT_MOUSE=$(yabai -m config mouse_follows_focus)
    echo "$CURRENT_FOCUS" > /tmp/yabai_focus_backup
    echo "$CURRENT_MOUSE" > /tmp/yabai_mouse_backup

    # フォーカス設定を無効化（先に実行）
    yabai -m config focus_follows_mouse off
    yabai -m config mouse_follows_focus off

    # ウィンドウをフロート化してグリッド配置
    yabai -m window --toggle float
    sleep 0.1
    yabai -m window --grid 10:10:1:1:8:8

    # HazeOverを有効化（activateを使わずに直接enableだけ）
    osascript -e 'tell application "HazeOver" to set enabled to true'

    # 最後にフォーカスを明示的に設定（HazeOver後に実行）
    yabai -m window --focus "${WINDOW_ID}"

    # 復元スクリプト実行
    /tmp/yabai-restore/${WINDOW_ID}.restore 2>/dev/null || true
else
    # （else部分は変更なし）
    # HazeOverを無効化
    osascript -e 'tell application "HazeOver" to set enabled to false'
    # ウィンドウをタイル化
    yabai -m window --toggle float
    # 保存された位置情報を復元
    if [ -f /tmp/yabai_window_${WINDOW_ID}_backup ]; then
        SAVED_POSITION=$(cat /tmp/yabai_window_${WINDOW_ID}_backup)
        SAVED_X=$(echo "$SAVED_POSITION" | cut -d',' -f1)
        SAVED_Y=$(echo "$SAVED_POSITION" | cut -d',' -f2)
        SAVED_W=$(echo "$SAVED_POSITION" | cut -d',' -f3)
        SAVED_H=$(echo "$SAVED_POSITION" | cut -d',' -f4)
        # 元の位置とサイズに復元
        yabai -m window --move "abs:${SAVED_X}:${SAVED_Y}"
        yabai -m window --resize "abs:${SAVED_W}:${SAVED_H}"
        # 一時ファイルを削除
        rm /tmp/yabai_window_${WINDOW_ID}_backup
    fi
    # 既存の復元スクリプトも実行（もしあれば）
    /tmp/yabai-restore/${WINDOW_ID}.restore 2>/dev/null || true
    # フォーカスを維持
    yabai -m window --focus "${WINDOW_ID}"
    # 保存されたフォーカス設定を復元
    if [ -f /tmp/yabai_focus_backup ] && [ -f /tmp/yabai_mouse_backup ]; then
        SAVED_FOCUS=$(cat /tmp/yabai_focus_backup)
        SAVED_MOUSE=$(cat /tmp/yabai_mouse_backup)
        yabai -m config focus_follows_mouse "$SAVED_FOCUS"
        yabai -m config mouse_follows_focus "$SAVED_MOUSE"
        # 一時ファイルを削除
        rm /tmp/yabai_focus_backup /tmp/yabai_mouse_backup
    else
        # デフォルト設定に戻す（お使いの環境に合わせて調整）
        yabai -m config focus_follows_mouse autoraise
        yabai -m config mouse_follows_focus on
    fi
fi
