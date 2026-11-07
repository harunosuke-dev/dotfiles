--- 組み込みのメッセージ UI（vim._core.ui2）を使う試み。
---
--- noice を外せるかを見るためのもの。このブランチでは既定で有効で、
--- NVIM_UI2=0 で起動した時だけ noice に戻る。
---
--- ui2 は 0.12 で入った実験的な機能で、cmdline とメッセージを
--- 専用のフロートへ出す。noice と同時には動かない（どちらも ext_messages を取る）
local M = {}

--- ui2 を使う構成かどうか
function M.enabled()
  return vim.g.core_ui2 == true
end

function M.setup()
  if not M.enabled() then
    return
  end

  require('vim._core.ui2').enable({
    msg = {
      -- 通常のメッセージは cmdline の行に出す。
      -- 'msg'（右下の独立した窓）は snacks の通知と場所が重なる
      target = 'cmd',
      -- :messages と長いメッセージは pager へ。画面いっぱいまで広がる
      targets = { [''] = 'cmd', confirm = 'dialog', list_cmd = 'pager' },
      cmd = { height = 0.5 },
      msg = { height = 0.5, timeout = 4000 },
      pager = { height = 1 },
    },
  })
end

return M
