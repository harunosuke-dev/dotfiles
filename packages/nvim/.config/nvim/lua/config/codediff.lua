--- codediff のタブまわりの後始末。
---
--- 差分を閉じた後に何も無い画面が残るのと、tabnew で生まれた空のバッファが
--- 一覧に残るのを防ぐ。プラグインの spec（lua/plugins/git.lua）から切り出した
local M = {}

--- そのタブが差分を映しているか
local function shows_diff(tab)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return false
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match('^codediff') then
      return true
    end
  end
  return false
end

--- 名前も中身も無いバッファを捨てる。
--- codediff は tabnew でタブを作るため、そこで生まれた空のバッファが
--- 窓から外れた後も一覧に残り、]b や <Space>fb に無名の行が混ざる
function M.wipe_blank_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local blank = vim.bo[buf].buflisted
      and vim.bo[buf].buftype == ''
      and vim.api.nvim_buf_get_name(buf) == ''
      and not vim.bo[buf].modified
      and #vim.fn.win_findbuf(buf) == 0
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
    if blank then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

function M.setup()
  -- 差分を閉じたらファイラを出す。codediff は最後の1枚でも空のタブを
  -- 作ってから閉じるので（ui/lifecycle/cleanup.lua）、nvim は終わらない。
  -- 残った窓をそのままファイラにする。
  -- 開いていたファイルはバッファとして残るので ]b や <Space>fb で戻れる
  vim.api.nvim_create_autocmd('User', {
    pattern = 'CodeDiffClose',
    group = vim.api.nvim_create_augroup('user_codediff_tabs', { clear = true }),
    callback = function()
      vim.schedule(function()
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
          if shows_diff(tab) then
            return -- 別の差分がまだ開いている
          end
        end
        pcall(vim.cmd, 'Oil')
        M.wipe_blank_buffers()
      end)
    end,
  })
end

return M
