--- codediff のタブを入口ごとに1枚だけ持つ。
---
--- codediff はタブページ単位で差分を持てるため、同じキーを押すたびにタブが増える
--- （ui/lifecycle/session.lua の active_diffs）。入口と開いたタブを覚えておき、
--- 生きていればそこへ飛ぶ。
---
--- 入口ごとに分けるのは、見ている範囲が違うため。作業ツリーの差分と履歴を
--- 1枚に押し込めると、押すたびに組み直すことになる。
local M = {}

--- 入口 → タブページ
local tabs = {}

--- 入口 → その時に対象としたもの（ファイル履歴のパスなど）。
--- 同じ入口でも対象が変われば開き直す
local targets = {}

--- :CodeDiff を呼んでから User CodeDiffOpen が来るまでの間だけ入る。
--- scratch は「差分のタブから呼んだ時に逃げ場として作ったタブ」
local pending

--- 常に左端へ置く入口。最初に見るものなので位置を固定する
local PINNED = 'changes'

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

--- 指定した入口の差分を開く。既に開いていればそのタブへ飛ぶ
--- @param entry string 入口の名前。タブを覚える鍵になる
--- @param cmd string 実行する :CodeDiff の行
--- @param target string? 対象。ファイル履歴のように入口が同じでも中身が変わる場合に渡す
--- @return boolean 開いたか飛べたか
function M.open(entry, cmd, target)
  local tab = tabs[entry]
  if tab and shows_diff(tab) then
    if targets[entry] == target then
      vim.api.nvim_set_current_tabpage(tab)
      return true
    end
    -- 入口は同じでも対象が違う。古い方を畳んでから開き直す。
    -- 先に pending を立てて、閉じた拍子にファイラが出るのを止める
    pending = { entry = entry }
    pcall(vim.cmd, vim.api.nvim_tabpage_get_number(tab) .. 'tabclose')
  end
  tabs[entry] = nil
  targets[entry] = target

  -- 差分のタブから呼ぶと、そのタブの差分が置き換わる。
  -- 別のタブへ出てから開き、空になった逃げ場は開き終わりに畳む
  local scratch
  if shows_diff(vim.api.nvim_get_current_tabpage()) then
    vim.cmd('tabnew')
    scratch = vim.api.nvim_get_current_tabpage()
  end

  pending = { entry = entry, scratch = scratch }
  if pcall(vim.cmd, cmd) then
    return true
  end

  pending = nil
  if scratch and vim.api.nvim_tabpage_is_valid(scratch) then
    pcall(vim.cmd, vim.api.nvim_tabpage_get_number(scratch) .. 'tabclose')
  end
  return false
end

function M.setup()
  local group = vim.api.nvim_create_augroup('user_codediff_tabs', { clear = true })

  -- :CodeDiff から戻った時点ではまだタブが無い。
  -- codediff は開き終わりに User CodeDiffOpen を出し、data にタブを載せる
  -- （ui/view/side_by_side.lua）。そこで覚える
  vim.api.nvim_create_autocmd('User', {
    pattern = 'CodeDiffOpen',
    group = group,
    callback = function(args)
      local tab = args.data and args.data.tabpage
      if not pending or not tab then
        return
      end
      local entry, scratch = pending.entry, pending.scratch
      pending = nil
      tabs[entry] = tab

      -- 組み立ての最中なので、終わってから畳む
      vim.schedule(function()
        if scratch and vim.api.nvim_tabpage_is_valid(scratch) then
          pcall(vim.cmd, vim.api.nvim_tabpage_get_number(scratch) .. 'tabclose')
          M.wipe_blank_buffers()
        end
        if entry == PINNED and vim.api.nvim_tabpage_is_valid(tab) then
          local current = vim.api.nvim_get_current_tabpage()
          vim.api.nvim_set_current_tabpage(tab)
          pcall(vim.cmd, 'tabmove 0')
          if vim.api.nvim_tabpage_is_valid(current) then
            vim.api.nvim_set_current_tabpage(current)
          end
        end
      end)
    end,
  })

  -- 差分を閉じて何も残らなかった時だけファイラを出す。
  --
  -- codediff は最後の1枚でも空のタブを作ってから閉じるので
  -- （ui/lifecycle/cleanup.lua）、nvim は終わらず空の画面が残る。そこを埋める。
  -- 編集していたファイルが残っている時に割り込むと、見ていたものを奪うことになる
  vim.api.nvim_create_autocmd('User', {
    pattern = 'CodeDiffClose',
    group = group,
    callback = function()
      -- 別の差分を開く途中の閉じは、入れ替えの一部なので触らない
      if pending then
        return
      end
      vim.schedule(function()
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
          if shows_diff(tab) then
            return -- 別の差分がまだ開いている
          end
        end
        local buf = vim.api.nvim_get_current_buf()
        local blank = vim.api.nvim_buf_get_name(buf) == ''
          and vim.bo[buf].buftype == ''
          and vim.api.nvim_buf_line_count(buf) == 1
          and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
        if blank then
          pcall(vim.cmd, 'Oil')
        end
        M.wipe_blank_buffers()
      end)
    end,
  })
end

return M
