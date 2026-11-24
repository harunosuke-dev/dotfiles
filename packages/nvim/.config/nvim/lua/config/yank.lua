--- 場所を伝えるためのヤンク。
---
--- AI エージェントに「どこの話か」を渡す時、パスと行番号を手で打っていた。
--- git のルートからの相対で出すのは、相手がリポジトリの中で見るため。
--- リポジトリの外では `~` 起点の絶対パスに落とす。
---
--- 行番号の区切りに `#L` を使うのは GitHub の URL と同じ綴りで、
--- 貼った先で何の数字か分かるため
local M = {}

--- git のルート。見つからなければ nil
local function git_root(path)
  return vim.fs.root(path, '.git')
end

--- 今のファイルのパスと行番号。
--- @param absolute boolean 絶対パスで出すか
--- @return string? text クリップボードへ入れる文字列
local function location(absolute)
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' or vim.bo.buftype ~= '' then
    vim.notify('名前の付いたファイルでのみ使える', vim.log.levels.WARN)
    return nil
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  if absolute then
    return vim.fn.fnamemodify(file, ':p') .. '#L' .. line
  end

  local root = git_root(file)
  local shown = root and vim.fs.relpath(root, file) or vim.fn.fnamemodify(file, ':~')
  return shown .. '#L' .. line
end

--- パスと行番号をクリップボードへ入れる
--- @param absolute boolean?
function M.location(absolute)
  local text = location(absolute or false)
  if not text then
    return
  end
  vim.fn.setreg('+', text)
  vim.notify(text, vim.log.levels.INFO, { title = 'コピーした' })
end

--- treesitter の名前と Markdown の言語名が違うもの。
--- 書かないものはそのまま使う（lua、json、css など）
local LANGS = {
  typescriptreact = 'tsx',
  javascriptreact = 'jsx',
  typescript = 'ts',
  javascript = 'js',
  markdown = 'md',
}

--- 選択範囲を Markdown のコードブロックとしてクリップボードへ入れる。
---
--- ファイル名と開始行を情報文字列に添える。貼った先で場所が分かるようにするため。
--- 貼り付け先が GitHub でも、言語名だけは解釈されて色が付く
function M.codeblock()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' or vim.bo.buftype ~= '' then
    vim.notify('名前の付いたファイルでのみ使える', vim.log.levels.WARN)
    return
  end

  -- ビジュアルモードを抜けた直後に呼ばれるので '< '> から取る
  local first = vim.fn.line("'<")
  local last = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)

  local root = git_root(file)
  local shown = root and vim.fs.relpath(root, file) or vim.fn.fnamemodify(file, ':~')
  local lang = LANGS[vim.bo.filetype] or vim.bo.filetype

  local fence = { ('```%s filename="%s" line=%d'):format(lang, shown, first) }
  vim.list_extend(fence, lines)
  fence[#fence + 1] = '```'

  vim.fn.setreg('+', table.concat(fence, '\n') .. '\n')
  vim.notify(('%s の %d 行'):format(shown, #lines), vim.log.levels.INFO, { title = 'コピーした' })
end

return M
