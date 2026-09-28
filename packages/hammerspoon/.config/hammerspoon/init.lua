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

-- hidutil が変換した後のキーコード（F18）
local F18 = 0x4F

-- 押している間に他のキーが入っても、何も起きないようにする。
-- 元が cmd のキーなので、押しながら別のキーを叩く癖が残っており、
-- そのまま通すと文字が紛れ込む
local f18Held = false
local f18HeldAt = 0

-- WARNING: keyUp を取りこぼした時に f18Held が立ったままになると、
-- すべてのキー入力が止まる。押しっぱなしのまま時間が経った場合は
-- ブロックを解く。キーリピートが無効な環境でも復帰できるようにする
local HOLD_LIMIT = 2

-- eventtap も watcher と同じくグローバルに保持する
keyTap = hs.eventtap.new({
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.keyUp,
}, function(event)
  local isKeyDown = event:getType() == hs.eventtap.event.types.keyDown
  local code = event:getKeyCode()

  if code == F18 then
    -- 押した瞬間だけ切り替える。キーリピートでは反応させない
    if isKeyDown and not f18Held then
      toggleSource()
    end
    f18Held = isKeyDown
    f18HeldAt = hs.timer.secondsSinceEpoch()
    return true
  end

  -- toggleSource が送った英数 / かなは通す。
  -- F18 を押した直後に届くので、下のブロックに巻き込むと切り替わらない
  if code == EISU or code == KANA then
    return false
  end

  if isKeyDown and f18Held and hs.timer.secondsSinceEpoch() - f18HeldAt < HOLD_LIMIT then
    return true
  end

  -- keyUp は通す。押し下げだけ捨てると、キーが押されたままにならない
  return false
end)
keyTap:start()
