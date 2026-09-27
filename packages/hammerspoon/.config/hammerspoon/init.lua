-- ~/.config/hammerspoon/init.lua
-- 入力ソース（英数 / かな）の切り替えをまとめている。

local ENGLISH_SOURCE = "com.apple.keylayout.ABC"

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

-- 右 cmd で英数とかなをトグルする。
-- 外部キーボードには地球儀キーが無く、macOS 標準の ctrl + alt + space も押しづらいため。
--
-- 右 cmd は hidutil で F18 へ変更してある（nix/darwin.nix）。
-- 修飾キーのまま残すと、右 cmd + space などの誤爆が起きる。
-- ここでは変更後の F18 を受ける

-- JIS キーボードの英数キーとかなキー。
-- 入力ソースを TIS で直接指定するより、IME にキーを渡す方が切り替わりが速い。
-- 合成したイベントなので、手元のキーボードが US 配列でも届く
local EISU = 0x66
local KANA = 0x68

-- 英数以外はすべて日本語入力とみなす（カタカナなどの派生ソースも英数へ戻す）
local function toggleSource()
  if hs.keycodes.currentSourceID() == ENGLISH_SOURCE then
    hs.eventtap.keyStroke({}, KANA, 0)
  else
    hs.eventtap.keyStroke({}, EISU, 0)
  end
end

hs.hotkey.bind({}, "f18", toggleSource)
