--- プロジェクトの package.json をフロートで覗く。
---
--- 依存の名前やスクリプト名を確かめたいだけの場面が多く、
--- そのために窓を割ったりバッファを切り替えたりするのが煩わしかった。
--- package-info が行末に最新版を出すので、開いた時点で更新の要否も分かる
local M = {}

--- 閉じるキーはこの窓にいる間だけ効かせる。
--- package.json は後で普通に開くこともあるため、バッファに残さない
local function map_close(win, buf)
  local group = vim.api.nvim_create_augroup('user_package_json_' .. win, { clear = true })
  for _, lhs in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', lhs, function()
      pcall(vim.api.nvim_win_close, win, false)
    end, { buffer = buf, nowait = true, desc = 'Close the package.json float' })
  end
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    pattern = tostring(win),
    callback = function()
      for _, lhs in ipairs({ 'q', '<Esc>' }) do
        pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
      end
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end

--- 今のファイルから上に辿って見つかる package.json を開く。
--- モノレポではワークスペースのものが先に当たる
function M.open()
  local from = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(from ~= '' and from or vim.fn.getcwd(), 'package.json')
  if not root then
    vim.notify('package.json が見つからない', vim.log.levels.WARN)
    return
  end

  local path = root .. '/package.json'
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    title = ' ' .. vim.fn.fnamemodify(root, ':t') .. '/package.json ',
    title_pos = 'center',
  })
  vim.wo[win].cursorline = true

  map_close(win, buf)
end

return M
