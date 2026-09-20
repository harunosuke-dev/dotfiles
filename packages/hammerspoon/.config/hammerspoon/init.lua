-- ~/.config/hammerspoon/init.lua
-- 入力ソース（英数 / かな）の切り替えをまとめている。

local ENGLISH_SOURCE = "com.apple.keylayout.ABC"
local JAPANESE_SOURCE = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

-- 現在が英数でなければ英数へ切り替える（無駄な切替を避ける）
local function toEnglish()
  if hs.keycodes.currentSourceID() ~= ENGLISH_SOURCE then
    hs.keycodes.currentSourceID(ENGLISH_SOURCE)
  end
end

-- アプリを切り替えるたびに入力ソースを英数へリセットする。
-- 日本語入力の状態で別アプリへ移る/戻ると、自動で英数入力になる。
-- watcher はグローバルに保持しないと GC で停止するため local にしない。
appWatcher = hs.application.watcher.new(function(_appName, eventType, _appObject)
  if eventType == hs.application.watcher.activated then
    toEnglish()
  end
end)
appWatcher:start()

-- 右 cmd の単押しで英数とかなをトグルする。
-- 外部キーボードには地球儀キーが無く、macOS 標準の ctrl + alt + space も押しづらいため。
-- 他のキーやマウスと組み合わせた時は、通常の cmd として働く。
local RIGHT_CMD = 0x36

-- 右 cmd を単独で押している間だけ true。間に他の入力が挟まれば倒す
local rightCmdAlone = false

local function toggleSource()
  if hs.keycodes.currentSourceID() == ENGLISH_SOURCE then
    hs.keycodes.currentSourceID(JAPANESE_SOURCE)
  else
    hs.keycodes.currentSourceID(ENGLISH_SOURCE)
  end
end

-- eventtap も watcher と同じくグローバルに保持する
cmdTap = hs.eventtap.new({
  hs.eventtap.event.types.flagsChanged,
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.leftMouseDown,
  hs.eventtap.event.types.rightMouseDown,
  hs.eventtap.event.types.otherMouseDown,
  hs.eventtap.event.types.scrollWheel,
}, function(event)
  if event:getType() ~= hs.eventtap.event.types.flagsChanged then
    rightCmdAlone = false
    return false
  end

  local flags = event:getFlags()

  if event:getKeyCode() == RIGHT_CMD and flags:containExactly({ "cmd" }) then
    rightCmdAlone = true
  else
    -- cmd が離れた時だけ発火する。修飾キーが増えた場合は候補を捨てるだけ
    if rightCmdAlone and not flags.cmd then
      toggleSource()
    end
    rightCmdAlone = false
  end

  return false
end)
cmdTap:start()
