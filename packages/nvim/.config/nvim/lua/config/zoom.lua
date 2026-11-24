--- 窓の最大化。
---
--- 素の Ctrl+w _ と Ctrl+w | でも最大化はできるが、戻すのは Ctrl+w = の等分で、
--- 元の配分は失われる。winrestcmd()（復元用の :resize 列）を控えておく。
---
--- 最大化したまま隣の窓へ移ると、移った先を最大化し直す。tmux のペインの
--- ズームと同じ動き（packages/tmux/.config/tmux/tmux.conf）。控えは最初のものを
--- 保つので、どの窓で解除しても元の配分へ戻る
local M = {}

--- 今の窓を画面いっぱいに広げる
local function maximize()
  vim.cmd('resize | vertical resize')
end

--- 控えはタブごとに持つ（vim.t.zoom_restore）。別のタブで押した時に
--- 噛み合わなくなるため
function M.toggle()
  if vim.t.zoom_restore then
    -- 最大化中に窓を開閉すると控えが合わなくなるので包む
    pcall(vim.cmd, vim.t.zoom_restore)
    vim.t.zoom_restore = nil
    return
  end
  vim.t.zoom_restore = vim.fn.winrestcmd()
  maximize()
end

function M.setup()
  vim.api.nvim_create_autocmd('WinEnter', {
    group = vim.api.nvim_create_augroup('user_zoom', { clear = true }),
    callback = function()
      -- フロート（ピッカー・ホバー）は広げない。閉じて戻った時に元の窓が当たる
      if vim.t.zoom_restore and vim.api.nvim_win_get_config(0).relative == '' then
        maximize()
      end
    end,
  })
end

return M
