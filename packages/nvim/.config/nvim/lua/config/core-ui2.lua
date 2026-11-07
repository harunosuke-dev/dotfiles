--- 組み込みのメッセージ UI（vim._core.ui2）を使う。
---
--- noice を外せるかを見るためのもの。このブランチでは既定で有効で、
--- NVIM_UI2=0 で起動した時だけ noice に戻る。
---
--- ui2 は 0.12 で入った実験的な機能で、cmdline とメッセージを専用の窓へ出す。
--- noice と同時には動かない（どちらも ext_messages を取る）
local M = {}

--- メッセージの行き先。ui2 は4つの窓を持ち、kind ごとに振り分けられる。
---
--- cmd    … コマンド行。入力欄と同じ場所に1行で出る
--- msg    … 右下の小窓。枠が付き、一定時間で消える
--- pager  … 広い窓。消えずに残り、スクロールできる
--- dialog … 入力を待つ問いかけ
---
--- 方針は noice の見た目に寄せている。
--- 軽い知らせは右下（noice の mini 相当）、読ませたいものは pager、
--- 検索や補完のように入力の続きとして出るものは cmd に置く
local TARGETS = {
  -- 軽い知らせ。読み飛ばしても困らないもの
  [''] = 'msg',
  echo = 'msg',
  echomsg = 'msg',
  lua_print = 'msg',
  bufwrite = 'msg',
  undo = 'msg',
  quickfix = 'msg',
  wmsg = 'msg',
  shell_ret = 'msg',
  progress = 'msg',

  -- 読ませたいもの。消えずに残す
  emsg = 'pager',
  echoerr = 'pager',
  lua_error = 'pager',
  rpc_error = 'pager',
  shell_cmd = 'pager',
  shell_err = 'pager',
  shell_out = 'pager',
  verbose = 'pager',
  list_cmd = 'pager',

  -- 入力の続きとして出るもの。コマンド行から動かさない
  empty = 'cmd',
  search_cmd = 'cmd',
  search_count = 'cmd',
  completion = 'cmd',
  wildlist = 'cmd',
  typed_cmd = 'cmd',
  confirm = 'cmd',
}

--- ui2 を使う構成かどうか
function M.enabled()
  return vim.g.core_ui2 == true
end

--- noice が持っていた <leader>n* の代わり。
---
--- Noice コマンドは noice を読み込まない構成では存在しない。
--- 通知は snacks が持っているので履歴と消去はそちらへ回す。
--- 「直前のメッセージ」と「エラーだけ」に当たるものは無く、:messages と g< で見る
local function map_notification_keys()
  vim.keymap.set('n', '<leader>nh', function()
    require('snacks').notifier.show_history()
  end, { desc = '[N]otification [h]istory' })

  vim.keymap.set('n', '<leader>nd', function()
    require('snacks').notifier.hide()
  end, { desc = '[N]otification [d]ismiss all' })

  vim.keymap.set('n', '<leader>nm', '<cmd>messages<cr>', { desc = '[N]otification [m]essages' })
end

function M.setup()
  if not M.enabled() then
    return
  end

  map_notification_keys()

  require('vim._core.ui2').enable({
    msg = {
      target = 'msg',
      targets = TARGETS,
      cmd = { height = 0.5 },
      dialog = { height = 0.5 },
      -- 表示時間は noice の mini（4秒）に合わせる。
      -- 右上に出る snacks の通知（6秒）より短くし、軽い知らせとして扱う
      msg = { height = 0.3, timeout = 4000 },
      pager = { height = 0.5 },
    },
  })
end

return M
