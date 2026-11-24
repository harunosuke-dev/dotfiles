--- Next.js の手元の資料（node_modules/next/dist/docs/）のリンクを gf で辿る。
---
--- 資料の中のリンクは nextjs.org の道筋（/docs/app/api-reference/…）で書かれている。
--- 手元のフォルダは番号付き（01-app/03-api-reference/…）なので、名前がそのままでは合わない。
--- marksman の gd も、手元のファイルを探すので見つけられない。
---
--- 手元に無いページ（/docs/messages/… のエラーの説明）は nextjs.org をブラウザで開く
local M = {}

local site = 'https://nextjs.org'

--- 頭の番号（03-）を除いた名前で比べる
local function find_entry(dir, segment, want_file)
  for name, kind in vim.fs.dir(dir) do
    local base = name:gsub('^%d+%-', '')
    if want_file and kind == 'file' and base == segment .. '.md' then
      return dir .. '/' .. name
    end
    if not want_file and kind == 'directory' and base == segment then
      return dir .. '/' .. name
    end
  end
end

--- /docs/app/… を手元の md の道筋にする。見つからなければ nil
local function resolve(path, root)
  local dir = root
  local segments = vim.split(path, '/', { trimempty = true })
  for i, segment in ipairs(segments) do
    if i == #segments then
      local file = find_entry(dir, segment, true)
      if file then
        return file
      end
      -- 段の名前が、フォルダの index.md を指すこともある（/docs/app など）
      local sub = find_entry(dir, segment, false)
      if sub and vim.uv.fs_stat(sub .. '/index.md') then
        return sub .. '/index.md'
      end
      return nil
    end
    dir = find_entry(dir, segment, false)
    if not dir then
      return nil
    end
  end
end

--- 見出しの文字を、リンクの #… と同じ形にする（`dynamic` → dynamic）
local function slug(heading)
  return heading:lower():gsub('[^%w%s%-]', ''):gsub('%s+', '-')
end

local function jump_to_heading(anchor)
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    local heading = line:match('^#+%s+(.+)$')
    if heading and slug(heading) == anchor then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      return
    end
  end
end

--- カーソルのある [文字](/docs/…) のリンクを返す
local function link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  for first, url, last in line:gmatch('()%[[^%]]*%]%((/docs/[^)%s]+)%)()') do
    if first <= col and col < last then
      return url
    end
  end
end

local function follow(root)
  local url = link_under_cursor()
  if not url then
    -- 資料のリンクでなければ、ふつうの gf
    vim.cmd('normal! gf')
    return
  end
  local path, anchor = url:match('^/docs/([^#]+)#?(.*)$')
  local file = resolve(path, root)
  if not file then
    vim.ui.open(site .. url)
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(file))
  if anchor ~= '' then
    jump_to_heading(anchor)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('next_docs', { clear = true }),
    pattern = 'markdown',
    callback = function(args)
      local root = vim.api.nvim_buf_get_name(args.buf):match('^(.*/next/dist/docs)/')
      if not root then
        return
      end
      vim.keymap.set('n', 'gf', function()
        follow(root)
      end, { buffer = args.buf, desc = 'Next.js の資料のリンクを辿る' })
    end,
  })
end

return M
