--- lazygit から開いたファイルを、lazygit を起動したペインへ返す。
---
--- lazygit の `e` と `o` は os.edit / os.open を走らせる。既定の `nvim` では
--- lazygit の端末バッファの中に入れ子の nvim が立ち上がり、親には届かない。
--- `nvim --remote` を使うと親に届くが、既定で新しいタブに開くため配置が崩れる。
---
--- lazygit 側は --remote-send でここの edit() を呼ぶだけにしてある
--- （packages/lazygit/.config/lazygit/config.yml）。
--- 閉じる・戻る・開くを1つの関数でこの順に行う。
---
--- WARNING: lazygit へ q を送って閉じさせる方法は使えない。送信は非同期で、
--- 戻る処理が先に走ってフォーカスだけ移り、lazygit が開いたまま残る
local M = {}

--- lazygit を開いた時の窓。閉じられていれば nil として扱う
local origin_win

--- 今の窓を覚えてから lazygit を開く
function M.open()
  origin_win = vim.api.nvim_get_current_win()
  vim.cmd('LazyGit')
end

--- lazygit の端末を映している窓を畳む。
--- フロートで開くため、窓を閉じればバッファは隠れる
local function close_lazygit()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'lazygit' or vim.api.nvim_buf_get_name(buf):match('lazygit') then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

--- lazygit で選んだファイルを、起動したペインへ開く。
--- @param path string lazygit が渡すファイルのパス
--- @param line string|nil 行番号。os.editAtLine から渡る
function M.edit(path, line)
  close_lazygit()

  if origin_win and vim.api.nvim_win_is_valid(origin_win) then
    pcall(vim.api.nvim_set_current_win, origin_win)
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if line and line ~= '' then
    pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(line) or 1, 0 })
  end
end

return M
