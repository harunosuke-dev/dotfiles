--- 選択範囲を構文の単位で広げる・狭める。
---
--- 名前の付いた単位（関数・クラス・引数・括弧）は vaf / via / vi( で掴める。
--- 名前が無い単位（if ブロック、JSX の要素、チェーンの一段）は掴む手段が無かった。
---
--- nvim-treesitter の main ブランチは incremental_selection を持たないため、
--- vim.treesitter の API だけで組む
local M = {}

--- 広げた履歴。狭める時に戻る先として使う。バッファごとに持つ
--- @type table<integer, integer[][]>
local stack = {}

--- いまの選択範囲。ビジュアルモード中は v と . の2点から取る。
--- ノーマルモードではカーソル位置の1点を幅0の範囲として返す
--- @return integer[] range 0 起点の { 開始行, 開始列, 終了行, 終了列 }
local function current_range()
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    local pos = vim.api.nvim_win_get_cursor(0)
    return { pos[1] - 1, pos[2], pos[1] - 1, pos[2] }
  end
  local a = vim.fn.getpos('v')
  local b = vim.fn.getpos('.')
  local s = { a[2] - 1, a[3] - 1 }
  local e = { b[2] - 1, b[3] - 1 }
  if s[1] > e[1] or (s[1] == e[1] and s[2] > e[2]) then
    s, e = e, s
  end
  -- 終了列は「選択に含まれる最後の文字」なので、終端として扱うため1つ進める
  return { s[1], s[2], e[1], e[2] + 1 }
end

--- 行と列をバッファの中に収める。
---
--- 構文木の根は「最終行の次の行の0桁目」で終わることがあり、
--- そのままカーソルを置くと範囲外になる
local function clamp(row, col)
  local last = vim.api.nvim_buf_line_count(0) - 1
  row = math.max(0, math.min(row, last))
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
  return row, math.max(0, math.min(col, math.max(#line - 1, 0)))
end

--- 範囲を選び直す。すでにビジュアルモードなら一度抜けてから張り直す
local function select_range(range)
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! \27')
  end
  local srow, scol = clamp(range[1], range[2])
  -- 終了列は終端なので、最後の文字へ戻す
  local erow, ecol = clamp(range[3], range[4] - 1)
  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { erow + 1, ecol })
end

local function same(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

--- a が b を完全に含み、かつ b より広いか
local function wider(a, b)
  if same(a, b) then
    return false
  end
  local starts_before = a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
  local ends_after = a[3] > b[3] or (a[3] == b[3] and a[4] >= b[4])
  return starts_before and ends_after
end

--- 構文の単位で1段広げる
function M.expand()
  local buf = vim.api.nvim_get_current_buf()
  local range = current_range()

  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { range[1], range[2] } })
  if not ok or not node then
    return
  end

  -- いまの選択より広くなるまで親を辿る。
  -- 同じ範囲を持つノードが入れ子になっていることがあるため、一致では止めない
  while node do
    local sr, sc, er, ec = node:range()
    if wider({ sr, sc, er, ec }, range) then
      stack[buf] = stack[buf] or {}
      table.insert(stack[buf], range)
      select_range({ sr, sc, er, ec })
      return
    end
    node = node:parent()
  end
end

--- 1段戻す。広げた履歴が無ければ何もしない
function M.shrink()
  local buf = vim.api.nvim_get_current_buf()
  local history = stack[buf]
  if not history or #history == 0 then
    return
  end
  local range = table.remove(history)
  -- 最初の1段はカーソル位置（幅0）なので、選択を解いて戻す
  if range[1] == range[3] and range[2] == range[4] then
    vim.cmd('normal! \27')
    vim.api.nvim_win_set_cursor(0, { range[1] + 1, range[2] })
    return
  end
  select_range(range)
end

--- バッファを離れたら履歴を捨てる。行番号が変わると戻り先が意味を失う
function M.setup()
  vim.api.nvim_create_autocmd({ 'BufDelete', 'TextChanged' }, {
    group = vim.api.nvim_create_augroup('user_node_select', { clear = true }),
    callback = function(args)
      stack[args.buf] = nil
    end,
  })
end

return M
