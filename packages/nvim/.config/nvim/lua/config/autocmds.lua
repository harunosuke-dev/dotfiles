local augroup = function(name)
  return vim.api.nvim_create_augroup('user_' .. name, { clear = true })
end

-- yank した範囲を一瞬ハイライトして、何をコピーしたか目視できるようにする
vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup('highlight_yank'),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- ファイルを開き直した時に前回のカーソル位置へ戻す
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup('last_location'),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 巨大ファイルを開いた時に、バッファ全体を走査する処理を止める。
-- 13MB / 12万行の TypeScript で Treesitter の全体パースに 1.4 秒かかる実測があり、
-- 生成物・ログ・巨大 JSON を誤って開いた時にフリーズしたように見えるのを防ぐ。
--
-- 色は失われない。Treesitter の代わりに Vim の正規表現 syntax を使う。
-- こちらは画面に見えている範囲だけを遅延処理するため大きなファイルでも軽い。
-- 補完も buffer / path / snippet のソースは動き続ける（消えるのは LSP 由来のみ）
local BIGFILE_SIZE = 1.5 * 1024 * 1024

vim.api.nvim_create_autocmd('BufReadPre', {
  group = augroup('bigfile'),
  callback = function(args)
    local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(args.buf))
    if not stat or stat.size <= BIGFILE_SIZE then
      return
    end

    -- Treesitter と LSP 側はこのフラグを見て自分から降りる
    vim.b[args.buf].bigfile = true

    vim.opt_local.foldmethod = 'manual' -- Treesitter の foldexpr を評価させない
    vim.opt_local.undofile = false
    vim.opt_local.swapfile = false
    vim.opt_local.list = false

    -- filetype 判定より後に走らせる必要があるため schedule する
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        vim.bo[args.buf].syntax = vim.bo[args.buf].filetype
      end
    end)

    vim.notify(
      string.format(
        '巨大ファイル（%.1fMB）のため Treesitter と LSP を無効化しました',
        stat.size / 1024 / 1024
      ),
      vim.log.levels.WARN
    )
  end,
})

-- 日本語入力のまま normal モードに戻ると操作できないため、英字へ自動で切り替える。
--
--   InsertLeave  挿入モードを抜けた時。IME で変換中に <Esc> を押した場合、
--                1回目は IME が変換の取り消しに使って nvim に届かないため、
--                2回目で挿入モードを抜けてここが走る
--   FocusGained  tmux でペインを切り替えて nvim に戻ってきた時
--                （tmux.conf の focus-events on が前提）
--   CmdlineLeave コマンドラインを抜けた時
--   VimEnter     起動直後
--
-- 逆方向（英字 → 日本語）は行わない。macism が日本語への切り替えを受け付けず、
-- 指定してもエラーを返さないまま無視されるため。日本語を書く時は手動で切り替える
if vim.fn.has('mac') == 1 and vim.fn.executable('macism') == 1 then
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'FocusGained', 'CmdlineLeave', 'VimEnter' }, {
    group = augroup('ime_ascii'),
    callback = function()
      -- 非同期で実行する。同期だと毎回プロセス起動を待つことになる
      vim.system({ 'macism', 'com.apple.keylayout.ABC' })
    end,
  })
end

-- 外部で書き換えられたファイルを読み直す。
--
-- autoread は既定で有効だが、これは「変更に気づいた時に読み直す」という設定で、
-- 気づくきっかけを自分で作る必要がある。checktime を呼ばない限り、nvim に
-- 留まっている間はバッファが古いまま残る。
--
-- AI エージェントや git の操作でファイルが書き換わる場面が増えたため、
-- 画面に戻った時と手を止めた時に確認する。
--   FocusGained  他のペインやアプリから戻ってきた時（tmux の focus-events が前提）
--   BufEnter     別のバッファへ移った時
--   CursorHold   updatetime のあいだ操作が止まった時
--
-- コマンドラインを開いている最中に読み直すと入力が壊れるため避ける
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'TermClose', 'TermLeave' }, {
  group = augroup('checktime'),
  callback = function()
    if vim.o.buftype == '' and vim.fn.mode() ~= 'c' then
      vim.cmd('checktime')
    end
  end,
})

-- 差分モードの間はカーソル行の強調を切る。
--
-- CursorLine は文字色を持たないと「低優先度」になり（:help hl-CursorLine）、
-- DiffAdd などの背景に負けて色が出ない。その代わりに下線として描かれ、
-- 追加・削除の色に重なって読みにくくなる。
--
-- 差分を見ている間はどの行を見ているかより、どこが変わったかの方が重要なので
-- 強調ごと切る。差分を閉じれば戻る。
--
-- あわせて、変更行の色を左右で塗り分ける。
--
-- Neovim は変更行の地（DiffChange）も、その中で変わった文字（DiffText）も、
-- 左右の窓で同じグループを使う。グループの定義だけでは分けられないので、
-- 窓ごとに効く winhighlight で読み替える。
--   古い側（gitsigns:// で始まるインデックスの写し） → 赤
--   新しい側（編集中のファイル）                     → 緑
--
-- git や GitHub は変更を「削除（赤）+ 追加（緑）」の組として表すので、これで揃う
-- DiffTextAdd（変更行の中で挿入された文字）も左右どちらにも出るので同じ扱いにする。
-- 名前から新しい側だけかと思えるが、実際は古い側にも現れて赤の中に緑が混ざる
--
-- DiffAdd も同じ理由で振り分ける。これは「git で追加された行」ではなく
-- 「この窓にだけあって相手の窓には無い行」なので、削除した行は古い側で
-- DiffAdd になる。素通しだと左に緑が出て git と逆を向く
local DIFF_WINHL = {
  old = {
    'DiffAdd:DiffAddOld',
    'DiffChange:DiffChangeOld',
    'DiffText:DiffTextOld',
    'DiffTextAdd:DiffTextOld',
  },
  new = {
    'DiffAdd:DiffAddNew',
    'DiffChange:DiffChangeNew',
    'DiffText:DiffTextNew',
    'DiffTextAdd:DiffTextNew',
  },
}

--- 自分が足した読み替えを取り除いた winhighlight を返す
local function without_diff_winhl(value)
  local mine = {}
  for _, list in pairs(DIFF_WINHL) do
    for _, item in ipairs(list) do
      mine[item] = true
    end
  end
  local kept = {}
  for item in vim.gsplit(value, ',', { trimempty = true }) do
    if not mine[item] then
      kept[#kept + 1] = item
    end
  end
  return kept
end

vim.api.nvim_create_autocmd('OptionSet', {
  group = augroup('diff_window'),
  pattern = 'diff',
  callback = function()
    vim.wo.cursorline = not vim.wo.diff

    local kept = without_diff_winhl(vim.wo.winhighlight)
    if vim.wo.diff then
      local side = vim.api.nvim_buf_get_name(0):match('^gitsigns://') and 'old' or 'new'
      vim.list_extend(kept, DIFF_WINHL[side])
    end
    vim.wo.winhighlight = table.concat(kept, ',')
  end,
})

-- 読み直した時に気づけるよう通知する。黙って中身が変わると混乱するため。
-- どのファイルかを出す。複数が同時に書き換わる場面があるため
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  group = augroup('checktime_notify'),
  callback = function(args)
    vim.notify(vim.fn.fnamemodify(args.file, ':~:.') .. ' を読み直しました', vim.log.levels.WARN, {
      title = '外部で変更',
    })
  end,
})

--- 差分の操作の説明を画面下端に出す。
---
--- winbar は incline（窓の右上に出すファイル名）と重なる。ステータスラインは
--- lualine が globalstatus で1本にまとめており、窓ごとには描かれない。
--- 仮想テキストは差分の行合わせをずらす。残るのはフロート
local function open_diff_hint()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  -- do と dp は「今いる窓から見て」の向きなので、そのまま訳すと読み取りづらい。
  -- 実際に使うのは左の do と右の dp の2つで、どちらもディスクの行がバッファに入る。
  -- 1行に詰めると幅で切れるため、位置の説明と操作の説明で行を分ける
  local lines = {
    ' left = buffer   right = disk (never saved)',
    ' disk into buffer: do on the left, dp on the right'
      .. '   ]c [c = next / prev hunk   :w = save   :tabclose = close',
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local function position()
    return {
      relative = 'editor',
      row = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - #lines,
      col = 0,
      width = vim.o.columns,
      height = #lines,
      style = 'minimal',
      focusable = false,
      zindex = 40,
    }
  end

  local win = vim.api.nvim_open_win(buf, false, position())
  vim.wo[win].winhighlight = 'NormalFloat:Comment'

  vim.api.nvim_create_autocmd('VimResized', {
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return true -- 消えていたらこの autocmd も畳む
      end
      vim.api.nvim_win_set_config(win, position())
    end,
  })

  return win
end

--- 今のバッファとディスクの内容を並べて差分表示する。
---
--- :diffsplit % は使えない。同じファイルは既にバッファとして読まれており、
--- 開いても同じ（変更済みの）バッファが出て差分にならない。
--- ディスク側は空のバッファへ read ++edit で読み込む
local function diff_with_disk()
  local filetype = vim.bo.filetype
  local buffer_win = vim.api.nvim_get_current_win()

  -- splitright により、新しい窓は右に開く
  vim.cmd('vertical new')
  local disk_win = vim.api.nvim_get_current_win()
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.bo.filetype = filetype
  vim.cmd('read ++edit #')
  vim.cmd('0d_') -- read が残す先頭の空行を消す
  vim.cmd('diffthis')

  vim.api.nvim_set_current_win(buffer_win)
  vim.cmd('diffthis')

  -- 差分モードは foldlevel を 0 にするため、取り込んで一致した部分から
  -- 順に折りたたまれていく。消えたように見えるので、この差分では畳まない
  vim.wo[buffer_win].foldenable = false
  vim.wo[disk_win].foldenable = false

  local hint_win = open_diff_hint()

  -- ディスク側を閉じたら説明も片付ける
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(disk_win),
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(hint_win) then
        vim.api.nvim_win_close(hint_win, true)
      end
    end,
  })
end

vim.api.nvim_create_user_command('DiffDisk', diff_with_disk, {
  desc = '今のバッファとディスクの内容を差分表示する',
})

-- 未保存の変更があるところへ外部から書き込まれた時。
--
-- 素の確認（OK / Load File）は片方を捨てる二択で、統合する道が無い。
-- バッファは保ったまま差分を開き、どちらの行を残すか手元で選べるようにする。
-- 取り込んだら :w で確定し、差分のタブを閉じる。
--
-- 自動で開くのは今見ているバッファだけ。checktime は全バッファを見るため、
-- まとめて開くと画面が埋まる。他は通知だけ出し、:DiffDisk で開く
vim.api.nvim_create_autocmd('FileChangedShell', {
  group = augroup('file_changed_diff'),
  callback = function(args)
    -- 読み直しも破棄もしない。確認のプロンプトも出さない
    vim.v.fcs_choice = ''

    local name = vim.fn.fnamemodify(args.file, ':~:.')

    -- 消えた相手とは差分が取れない。ディスク側に中身が無い。
    -- バッファは残っているので、:w を押せばそのまま書き戻せる
    if vim.v.fcs_reason == 'deleted' then
      vim.notify(name .. ' が外部で削除された', vim.log.levels.WARN, {
        title = ':w で書き戻せる',
      })
      return
    end

    local current = args.buf == vim.api.nvim_get_current_buf()
    -- 今見ているバッファなら差分がそのまま開くので、通知は事実だけでよい。
    -- 表示時間は既定（6秒）に任せる。作業を終えた後まで残ると邪魔になる
    vim.notify(
      name .. ' が外部で変更された' .. (current and '' or '（:DiffDisk で差分表示）'),
      vim.log.levels.WARN,
      {
        title = '未保存の変更あり',
      }
    )

    if current then
      -- 今のレイアウトを壊さないよう、別のタブへ開く
      vim.schedule(function()
        vim.cmd('tab split')
        diff_with_disk()
      end)
    end
  end,
})

-- 文章を書くファイルで、折り返しの見た目を整える。
--
-- 折り返し自体は全ファイルで有効（lua/config/options.lua）。
-- 表が崩れる時は <Space>uw で切る。
--
--   breakindent  折り返した行もインデントを保つ
--   showbreak    折り返した行の先頭に印を出す
--
-- WARNING: linebreak は入れない。
-- 'breakat' が ASCII しか持てない。
-- そのため日本語では直前の空白まで戻って改行し、行の右半分が空く。
--
-- j / k と 0 / $ の表示行対応は全ファイル共通なので keymaps.lua にある
local prose_group = augroup('prose_wrap')

vim.api.nvim_create_autocmd('FileType', {
  group = prose_group,
  pattern = { 'markdown', 'mdx', 'text', 'gitcommit', 'gitrebase' },
  callback = function()
    vim.opt_local.linebreak = false
    vim.opt_local.breakindent = true
    vim.opt_local.showbreak = '↪ '
  end,
})

-- コミットメッセージで勝手に改行させない。
--
-- 標準の ftplugin が textwidth=72 と formatoptions+=t を入れるため、72桁を超えると
-- 直前の空白が改行に変わる。1文1行で書く方針と衝突するので t だけ外す。
-- textwidth は目安として残るので、整えたい時は gq が使える
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('no_auto_wrap'),
  pattern = 'gitcommit',
  callback = function()
    vim.opt_local.formatoptions:remove('t')
  end,
})

-- CSS の変数を書いたファイルを保存した時に、css_variables へ知らせる。
--
-- WARNING: このサーバは workspace/didChangeWatchedFiles でしか変数表を更新しない
-- （dist/index.js の onDidChangeWatchedFiles）。監視の登録はサーバ側で行わないため、
-- VSCode 以外では誰も通知を送らない。
-- 送らないと、新しく足した変数が補完にも色にも出てこない。
--
-- 通知の後で document_color を入れ直すのは、Neovim がクライアントごとに
-- 一度しか documentColor を聞かないため（lua/plugins/lsp.lua の注記を参照）
vim.api.nvim_create_autocmd('BufWritePost', {
  group = augroup('css_variables_sync'),
  pattern = { '*.css', '*.scss', '*.sass', '*.less' },
  callback = function(args)
    local clients = vim.lsp.get_clients({ name = 'css_variables' })
    if #clients == 0 then
      return
    end

    local uri = vim.uri_from_fname(vim.fn.fnamemodify(args.file, ':p'))
    for _, client in ipairs(clients) do
      client:notify('workspace/didChangeWatchedFiles', {
        changes = { { uri = uri, type = vim.lsp.protocol.FileChangeType.Changed } },
      })
    end

    -- 再解析を待ってから色を描き直す。
    -- 窓に出ているものだけでは足りない。定義側を同じ窓で開いて保存した場合、
    -- 参照している側は隠れていて対象から漏れる
    vim.defer_fn(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and #vim.lsp.get_clients({ bufnr = buf, name = 'css_variables' }) > 0 then
          vim.lsp.document_color.enable(false, { bufnr = buf })
          vim.lsp.document_color.enable(true, { bufnr = buf })
        end
      end
    end, 300)
  end,
})

-- quickfix ウィンドウの操作性を整える
local qf_group = augroup('quickfix')

vim.api.nvim_create_autocmd('FileType', {
  group = qf_group,
  pattern = { 'qf' },
  callback = function(args)
    -- flash.nvim が <CR> をグローバルに奪うため標準動作に戻す。
    -- quickfix の <CR>（該当箇所へジャンプ）はマッピングではなく Vim 組み込みの
    -- 挙動なので、グローバルマップがあると上書きされてしまう
    vim.keymap.set('n', '<CR>', '<CR>', { buffer = args.buf, remap = false, desc = 'Jump to the entry' })

    -- q で閉じる。未割り当てだと q がマクロ記録の開始になり、
    -- 一覧を閉じたつもりで記録が始まる事故が起きる。
    --
    -- 一覧は quicker によって編集可能になっている（lua/plugins/diagnostics.lua）。
    -- 書きかけのまま閉じると黙って消えるので、その時だけ止める
    vim.keymap.set('n', 'q', function()
      if vim.bo.modified then
        vim.notify('一覧に未反映の変更がある。:w で反映、:q! で捨てる', vim.log.levels.WARN)
        return
      end
      vim.cmd('cclose')
    end, { buffer = args.buf, desc = 'Close the list' })

    -- 一覧の窓でジャンプ履歴を辿らせない。
    --
    -- 素の挙動では、その窓に履歴の先のファイルが読み込まれる。
    -- 一覧が消えて、小さな窓にファイルだけが残る形になる。
    -- 履歴を辿るのは <CR> で飛んだ先でする
    for _, key in ipairs({ '<C-o>', '<C-i>' }) do
      vim.keymap.set('n', key, function()
        vim.notify('一覧では使えない。<CR> で飛んでから押す', vim.log.levels.WARN)
      end, { buffer = args.buf, desc = 'Not available in the list' })
    end

    -- j / k で一覧を上下するだけで、対象の位置を隣のウィンドウに追従表示する。
    -- 標準では <CR> を押すまで移動しないため、内容を確かめながら流し読みできない
    -- nested を付けないと、ここから開いたファイルの BufRead と FileType が
    -- 発火しない。nvim は autocmd の中から出る autocmd を既定で止めるため、
    -- まだ開いていないファイルへ飛ぶと filetype が付かず色も構文も無いまま出る
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = qf_group,
      buffer = args.buf,
      nested = true,
      callback = function()
        if vim.fn.getqflist({ size = 0 }).size == 0 then
          return
        end
        local qf_win = vim.api.nvim_get_current_win()
        -- keepjumps を付けないと、一覧を j / k でなぞるたびにジャンプ履歴が積まれ、
        -- あとで <C-o> を押しても元居た場所まで一気に戻れなくなる
        pcall(vim.cmd, 'keepjumps silent! cc ' .. vim.fn.line('.'))
        if vim.api.nvim_win_is_valid(qf_win) then
          vim.api.nvim_set_current_win(qf_win) -- フォーカスは一覧側に戻す
        end
      end,
    })
  end,
})

-- 新規ファイルを初めて保存した時に読み直す。
--
-- 保存すると filetype は判定され Treesitter の色も付くが、LSP だけは起動しない。
-- 読み直すと BufRead から走り直すため起動する。
--
-- BufWritePre の時点でバッファ名は既に付いているので、名前の有無では判定できない。
-- ディスクにまだ実体が無いことを新規ファイルの印にする。
--
-- undo 履歴は失われる。書き始めたばかりの新規ファイルに限るので許容する
local first_write = augroup('reload_after_first_write')

vim.api.nvim_create_autocmd('BufWritePre', {
  group = first_write,
  callback = function(args)
    -- oil のような実ファイルでないバッファ（buftype が空でない）は対象外。
    -- 名前が oil:/// で filereadable も 0 のため、新規ファイルと区別が付かない
    local name = vim.api.nvim_buf_get_name(args.buf)
    vim.b[args.buf].was_new_file = vim.bo[args.buf].buftype == '' and name ~= '' and vim.fn.filereadable(name) == 0
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  group = first_write,
  callback = function(args)
    if not vim.b[args.buf].was_new_file then
      return
    end
    vim.b[args.buf].was_new_file = nil
    -- BufWritePost の最中は読み直しが効かないため、書き込み完了後に回す
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        vim.api.nvim_buf_call(args.buf, function()
          vim.cmd.edit()
        end)
      end
    end)
  end,
})

-- 保存時に行末の余分な空白を削除する
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup('trim_whitespace'),
  callback = function(args)
    -- Markdown 系は行末の半角2スペースが「強制改行」を意味するため対象外にする
    local ft = vim.bo[args.buf].filetype
    if ft == 'markdown' or ft == 'mdx' then
      return
    end
    -- checkhealth の出力など読み取り専用バッファでは置換が E21 で失敗する
    if not vim.bo[args.buf].modifiable then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- カーソル行の帯は、今いる窓だけに出す。
--
-- 分割すると全ての窓に帯が出て、どこにカーソルがあるかが一目で分からない。
-- 帯は位置を示すためのものなので、読んでいる窓に1本だけあればよい。
--
-- WinLeave で消すのではなく、窓を移るたびにタブ内を一巡して当て直す。
-- codediff の explorer のように、プラグインが後から cursorline を立て直す窓が
-- あり、離れた時に一度消すだけでは戻ってしまう。
--
-- フロート窓（ピッカー・ホバー）は触らない。プラグイン側の指定を上書きしないため
--- quickfix の窓がこのタブにあるか。
--- 一覧と追従先は組で1つの画面なので、追従先にも帯を残す
local function has_quickfix()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'qf' then
      return true
    end
  end
  return false
end

local function follow_cursorline()
  local current = vim.api.nvim_get_current_win()
  -- 一覧をなぞると追従先のカーソルが動く。そこに帯が無いと、
  -- 今どの行を見ているのかが分からない
  local quickfix = has_quickfix()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == '' then
      -- 差分モードでは帯そのものを切っている（上の diff_window を参照）
      vim.wo[win].cursorline = (win == current or quickfix) and not vim.wo[win].diff
    end
  end
end

vim.api.nvim_create_autocmd({ 'WinEnter', 'WinNew', 'WinClosed', 'BufWinEnter', 'VimEnter', 'FileType' }, {
  group = augroup('cursorline_focus'),
  callback = vim.schedule_wrap(follow_cursorline),
})

-- 非アクティブなウィンドウを沈ませる。
--
-- 窓ごとのハイライト名前空間を当てて、その窓の色だけ暗くする。背景を敷いて
-- 見分ける方法だと透過が切れるため、色を落とすだけで済ませる。
-- 名前空間の中身は lua/config/highlights.lua の M.build_inactive()。
--
-- 通常のファイルを開いている窓に限る。フロート窓（補完・ホバー）は今の
-- ウィンドウではないが読ませたい面なので触らない。
--
-- **差分モードの窓は対象外。** 名前空間は winhighlight より優先されるため、
-- 当てるとその窓の読み替えが丸ごと効かなくなる（上の DIFF_WINHL が死んで、
-- 新しい側まで赤くなる）。名前空間を外しても戻らないので、初めから触らない
--- nvim のペイン自体にフォーカスがあるか。
--- tmux で隣のペイン（Claude など）へ移ると false になる。
--- 外れている間は「今いる窓」も沈めて、nvim 全体が退いて見えるようにする。
--- tmux 側は focus-events on が前提（packages/tmux/.config/tmux/tmux.conf）
local focused = true

--- 一覧と中身が組で1つの画面になっているタブかどうか。
---
--- codediff は explorer と左右の差分が組になっている。
--- quickfix は一覧と追従先が組で、フォーカスは一覧にあっても
--- 読んでいるのは追従先の方になる。
--- どちらも窓を移るたびに片方が沈むと読めないので、タブごと対象から外す
local function is_paired_tab()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local filetype = vim.bo[buf].filetype
    if filetype:match('^codediff') or filetype == 'qf' then
      return true
    end
  end
  return false
end

local function dim_inactive_windows()
  -- 名前空間は iceberg 用にしか作らない。テーマ側に同じ仕組み
  -- （kanagawa の dimInactive）があるものはそちらに任せる
  local enabled = vim.g.colors_name == 'iceberg' and not is_paired_tab()
  local ns = require('config.highlights').inactive_ns()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == '' and not vim.wo[win].diff then
        -- 0 は大域の名前空間。当て直すのではなく外す側
        local dim = enabled and (not focused or win ~= current)
        vim.api.nvim_win_set_hl_ns(win, dim and ns or 0)
      end
    end
  end
end

vim.api.nvim_create_autocmd({ 'WinEnter', 'WinNew', 'WinClosed', 'BufWinEnter', 'VimEnter', 'ColorScheme' }, {
  group = augroup('dim_inactive_windows'),
  callback = vim.schedule_wrap(dim_inactive_windows),
})

-- 端末のフォーカスが移った時。tmux のペインを跨いだ時にここが呼ばれる
vim.api.nvim_create_autocmd({ 'FocusLost', 'FocusGained' }, {
  group = augroup('dim_on_focus'),
  callback = vim.schedule_wrap(function(args)
    focused = args.event == 'FocusGained'
    dim_inactive_windows()
  end),
})

-- キー列の待ち時間をモードごとに変える。
--
-- ノーマルモードには mini.surround の s 始まりのキーがある（saiw) など）。
-- s は単独でも <Nop> として成立するため、次のキーが timeoutlen 以内に来ないと
-- そこで確定してしまい、続きが素の操作として解釈される。150ms では
-- 250ms 間隔の打鍵で `saiw]` が `hiw]ello world` になった（実測）。
--
-- 一方で挿入モードは短いままにしたい。jk で抜ける割り当てがあり、長いと
-- 単独の j を打って止めた時の表示遅れがそのぶん伸びる。
--
-- options.lua の初期値は挿入モード側。ここでノーマルへ戻す時に伸ばす。
-- ノーマル側は Vim の既定値と同じ 1000。s を単独で押すと1秒待って何も
-- 起きないが、s は mini.surround が <Nop> にしているので失うものは無い
local TIMEOUTLEN = { insert = 150, normal = 1000 }

vim.api.nvim_create_autocmd('InsertEnter', {
  group = augroup('timeoutlen_by_mode'),
  callback = function()
    vim.o.timeoutlen = TIMEOUTLEN.insert
  end,
})

vim.api.nvim_create_autocmd({ 'InsertLeave', 'VimEnter' }, {
  group = augroup('timeoutlen_by_mode_leave'),
  callback = function()
    vim.o.timeoutlen = TIMEOUTLEN.normal
  end,
})
