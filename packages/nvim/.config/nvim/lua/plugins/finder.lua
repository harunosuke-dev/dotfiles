-- ホーム以下を検索する時に飛ばすもの。
--
-- ディレクトリは生成物と外部から取ってきたもの。拡張子は nvim で開いても
-- 意味の無いもの（写真・フォント・書庫・バイナリのデータ）。
-- これを外すと写真とデータだけで4万件を超え、目的のファイルが埋もれる。
local IGNORE_DIRS = {
  '.git',
  '.jj',
  'node_modules',
  '.next',
  'dist',
  'build',
  '.cache',
  '.venv',
  '__pycache__',
  'Library',
  '.Trash',
  '.local/share',
}

local IGNORE_EXTS = {
  -- 画像
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'heic',
  'bmp',
  'tiff',
  'ico',
  'icns',
  -- 動画・音声
  'mp4',
  'mov',
  'avi',
  'mkv',
  'mp3',
  'wav',
  'flac',
  'm4a',
  -- フォント
  'ttf',
  'otf',
  'woff',
  'woff2',
  'eot',
  -- 書庫・配布物
  'zip',
  'gz',
  'bz2',
  'xz',
  'tar',
  'dmg',
  'pkg',
  'app',
  'pdf',
  -- バイナリ・データ
  'dat',
  'toc',
  'journal',
  'thm',
  'plist',
  'sqlite',
  'sqlite3',
  'db',
  'o',
  'so',
  'dylib',
  'a',
  'class',
  'pyc',
  'wasm',
}

--- 拡張子は大文字も弾く。カメラから来たファイルは .JPG や .HEIC のことが多く、
--- fd の --exclude は大文字小文字を区別する
local function ext_globs()
  local globs = {}
  for _, ext in ipairs(IGNORE_EXTS) do
    globs[#globs + 1] = '*.' .. ext
    globs[#globs + 1] = '*.' .. ext:upper()
  end
  return globs
end

local function fd_excludes()
  local args = {}
  for _, dir in ipairs(IGNORE_DIRS) do
    args[#args + 1] = '--exclude ' .. vim.fn.shellescape(dir)
  end
  for _, glob in ipairs(ext_globs()) do
    args[#args + 1] = '--exclude ' .. vim.fn.shellescape(glob)
  end
  return table.concat(args, ' ')
end

local function rg_excludes()
  local args = {}
  for _, dir in ipairs(IGNORE_DIRS) do
    args[#args + 1] = "--glob '!" .. dir .. "/**'"
  end
  for _, glob in ipairs(ext_globs()) do
    args[#args + 1] = "--glob '!" .. glob .. "'"
  end
  return table.concat(args, ' ')
end

local HOME_FD_OPTS = '--color=never --type f --type l ' .. fd_excludes()

local HOME_RG_OPTS = '--column --line-number --no-heading --color=always --smart-case '
  .. '--max-columns=4096 '
  .. rg_excludes()

--- 同梱のカラースキームを除いた一覧を返す。
---
--- Neovim には blue や desert など30近くが同梱されており、入れたテーマが埋もれる。
--- 判定は名前ではなく「実際に読まれるファイルの場所」で行う。catppuccin のように
--- 同名の同梱版があるものは、rtp の手前に来るプラグイン側が残る
local function installed_colorschemes()
  local runtime = vim.fs.normalize(vim.env.VIMRUNTIME)
  return vim.tbl_filter(function(name)
    local found = vim.api.nvim_get_runtime_file('colors/' .. name .. '.*', false)[1]
    return not found or not vim.startswith(vim.fs.normalize(found), runtime)
  end, vim.fn.getcompletion('', 'color'))
end

--- 検索の範囲を表す。fzf-lua へそのまま渡すオプションを返す。
--- files に rg_opts を、live_grep に fd_opts を渡しても無視されるので、
--- 両方を持たせて1つの関数で済ませる

--- Neovim の今の場所（cwd）。fzf-lua へ何も渡さなければ既定で cwd を見る。
--- <Space>fp でプロジェクトへ移った後など、意図して絞っている場所をそのまま使う
local function scope_cwd()
  return {}
end

--- 今のバッファから見た git のルート。worktree や submodule の .git も拾う。
--- リポジトリの外では今の場所のまま動かす。
--- 一番よく押すキーに割り当てるため、外れた時も通知は出さない。
--- どこを見ているかはプロンプトのディレクトリ名で分かる
local function scope_root()
  local path = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(path ~= '' and path or vim.uv.cwd(), '.git')
  return {
    cwd = root,
    prompt = vim.fn.fnamemodify(root or vim.uv.cwd(), ':t') .. '❯ ',
  }
end

--- 手元のプロジェクトをまとめて。別のリポジトリの書き方を探す時に使う。
---
--- cwd をホームに置き、そこからの相対パスで対象を指定する。
--- fzf-lua は search_paths を cwd からの相対に直すため（providers/files.lua）、
--- こうすると一覧が Repos/... の形で出る。
---
--- 除外の指定は要らない。この下はすべて git の管理下で、fd も rg も
--- .gitignore に従うため node_modules などは最初から外れる。
--- 一覧に出す場所（lua/config/projects.lua）とは別物。あちらは owner 単位
local function scope_projects()
  return {
    cwd = vim.env.HOME,
    search_paths = { 'Repos', 'Projects', '.dotfiles' },
    prompt = 'Projects❯ ',
  }
end

--- ホーム以下。プロジェクト以外（書類や設定）まで探したい時に使う
local function scope_home()
  return {
    cwd = vim.env.HOME,
    prompt = 'Home❯ ',
    fd_opts = HOME_FD_OPTS,
    rg_opts = HOME_RG_OPTS,
  }
end

--- ファイル名で探す。Alt-g で同じ範囲の grep へ移れる。
--- 名前で見つからない時に、範囲を選び直さず中身の検索へ切り替えられる。
--- ctrl-g は fzf-lua が grep 系で使っている（grep と live_grep の切り替え）ため避ける。
--- ヘッダーに出すのは alt-i（.gitignore）と同じ流儀
local function find_files(scope)
  return function()
    local opts = scope()
    opts.actions = {
      ['alt-g'] = {
        fn = function()
          require('fzf-lua').live_grep(scope())
        end,
        header = 'Grep instead',
      },
    }
    require('fzf-lua').files(opts)
  end
end

--- 中身を検索する
local function find_grep(scope)
  return function()
    require('fzf-lua').live_grep(scope())
  end
end

--- 決まった語で検索する。カーソル下の語（grep_cword）や
--- 選択した文字列（grep_visual）を、同じ範囲で引く
local function find_word(picker, scope)
  return function()
    require('fzf-lua')[picker](scope())
  end
end

return {
  'ibhagwan/fzf-lua',
  cmd = 'FzfLua',
  keys = {
    -- ファイル系。範囲は4段階。
    --
    --   ;f / ;r   .git のルート（一番よく使うので ; に置く）
    --   ff / fg   今の場所（cwd）
    --   Ff / Fg   手元のプロジェクト全部
    --   FF / FG   ホーム全体
    { '<leader>ff', find_files(scope_cwd), desc = '[F]ind [F]ile in the current directory' },
    { '<leader>fg', find_grep(scope_cwd), desc = '[F]ind by [G]rep in the current directory' },
    { '<leader>fb', '<cmd>FzfLua buffers<cr>', desc = '[F]ind [B]uffer already open / <Space><Space>' },
    { '<leader>fr', '<cmd>FzfLua oldfiles<cr>', desc = '[F]ind [R]ecent across projects' },

    -- kickstart から引き継いだ別名。fb / f/ と同じものを、指が覚えている位置にも置く
    { '<leader><leader>', '<cmd>FzfLua buffers<cr>', desc = 'Find buffers already open / <Space>fb' },
    { '<leader>/', '<cmd>FzfLua blines<cr>', desc = 'Search in this file / <Space>f/' },

    -- 検索の範囲を今いるディレクトリの外へ広げる3つ。
    --
    -- ff / fg は「今いるディレクトリ配下」しか見ない。別のプロジェクトを触りたい
    -- 時は、まず fp で移動先を選ぶ。zoxide はシェルで z を使うたびに訪問先を
    -- 覚えているので、よく行く場所ほど上に出る。
    --
    -- FF / FG はホーム以下を直接なめる。設定ファイルや別プロジェクトを
    -- 「どこにあるか思い出せないまま」探す時用。
    {
      '<leader>fp',
      function()
        local projects = require('config.projects').list()
        -- 表示は ~ を短縮した形。zoxide のスコアは出さない（並び順で意味は足りる）
        local labels = vim.tbl_map(function(path)
          return vim.fn.fnamemodify(path, ':~')
        end, projects)

        require('fzf-lua').fzf_exec(labels, {
          prompt = 'Project❯ ',
          -- 表示は ~ を短縮した形なので、プレビューに渡す前に実体へ戻す
          preview = 'dir=$(printf %s {} | sed "s|^~|$HOME|"); '
            .. 'eza --tree --level=2 --icons=always --color=always "$dir" 2>/dev/null || ls -la "$dir"',
          actions = {
            -- 選んだディレクトリへ移動し、そのままファイル検索へ繋ぐ
            ['default'] = function(selected)
              if not selected or not selected[1] then
                return
              end
              local dir = vim.fn.expand(selected[1])
              vim.cmd.tcd(vim.fn.fnameescape(dir))
              vim.notify('移動しました: ' .. vim.fn.fnamemodify(dir, ':~'))
              -- ファイル一覧ではなくファイラで開く。中身を見ながら辿れるうえ、
              -- バッファとして残るので閉じても ]b や <Space>fb で戻れる
              require('oil').open(dir)
            end,
          },
        })
      end,
      desc = '[F]ind [P]roject : cd and browse',
    },

    -- 一番よく押すものだけ ; に寄せる。<Space> より1打鍵短く、待ち時間も無い。
    --
    -- 範囲は git のルート。cwd は <Space>fp が tcd で揃えるため普段は同じだが、
    -- scope_root はバッファから .git を探すので、submodule やサブディレクトリから
    -- 開いた時もそのファイルのリポジトリに付く。
    { ';f', find_files(scope_root), desc = 'Find a file in the git root' },
    { ';r', find_grep(scope_root), desc = 'Grep in the git root' },
    { ';;', '<cmd>FzfLua resume<cr>', desc = 'Reopen the last picker' },
    -- 手元のプロジェクトをまとめて横断する。別のリポジトリの書き方を探す時
    { '<leader>Ff', find_files(scope_projects), desc = '[F]ind [F]ile across projects' },
    { '<leader>Fg', find_grep(scope_projects), desc = '[F]ind by [G]rep across projects' },
    -- ホーム全体。プロジェクト以外（書類や設定）まで探す時だけ使う
    { '<leader>FF', find_files(scope_home), desc = '[F]ind [F]ile under home' },
    { '<leader>FG', find_grep(scope_home), desc = '[F]ind by [G]rep under home' },

    -- カーソル下の単語をそのまま検索。調べ物の起点として使用頻度が高い。
    --
    -- 範囲は cwd ではなく .git のルートに固定する。語の出どころを探す用途では
    -- リポジトリ全体を見た方が当たる。cwd に絞ると取りこぼす
    {
      '<leader>fw',
      find_word('grep_cword', scope_root),
      desc = '[F]ind [W]ord under cursor in the git root',
    },
    {
      '<leader>fw',
      find_word('grep_visual', scope_root),
      mode = 'x',
      desc = '[F]ind [W]ord from selection in the git root',
    },
    -- 現在のバッファ内だけを絞り込む。長いファイルの中を移動する時に速い
    { '<leader>f/', '<cmd>FzfLua blines<cr>', desc = '[F]ind [/] in this file / <Space>/' },
    { '<leader>fd', '<cmd>FzfLua diagnostics_document<cr>', desc = '[F]ind [D]iagnostics in this file' },
    { '<leader>fD', '<cmd>FzfLua diagnostics_workspace<cr>', desc = '[F]ind [D]iagnostics in project' },
    -- 直前の検索結果を条件ごと復元する。閉じてしまった時に打ち直さずに済む
    { '<leader>fR', '<cmd>FzfLua resume<cr>', desc = '[F]ind [R]esume : reopen last picker' },
    -- 設定・ヘルプ系
    { '<leader>fh', '<cmd>FzfLua helptags<cr>', desc = '[F]ind [H]elp tags' },
    {
      '<leader>fs',
      function()
        require('config.snippets').pick()
      end,
      desc = '[F]ind [S]nippet for this filetype',
    },
    { '<leader>fk', '<cmd>FzfLua keymaps<cr>', desc = '[F]ind [K]eymap' },
    -- git 系だが実体は fzf-lua なのでここに置く。
    -- 切り替えだけなら lazygit を開くより速い
    { '<leader>gb', '<cmd>FzfLua git_branches<cr>', desc = '[G]it [B]ranch : switch' },
    {
      '<leader>fc',
      function()
        require('fzf-lua').colorschemes({ colors = installed_colorschemes() })
      end,
      desc = '[F]ind [C]olorscheme : preview live',
    },
    { '<leader>fz', '<cmd>FzfLua<cr>', desc = '[F]ind all fzf-lua pickers' },
  },
  init = function()
    -- シェルの FZF_DEFAULT_OPTS を引き継がせない。
    --
    -- zsh 側で --preview（bat）や --bind を設定しており、fzf-lua がそれを
    -- そのまま受け取っていた。その結果、
    --   - Ctrl+n / Ctrl+p で候補を移動できない（プレビューの送りに潰れていた）
    --   - fzf-lua 自前のプレビューが bat に置き換わる
    -- という状態になっていた。zsh 側の割り当ては後に ctrl-u/d へ移したが、
    -- --preview や --color は依然として渡ってくるので、ここは残す。
    --
    -- 自前のプレビューは treesitter で色分けし、キーマップや LSP の結果など
    -- ファイル以外の候補にも対応している。bat で置き換わるとそれらが壊れる。
    -- 端末で直接 fzf を使う時の設定はそのまま残る
    vim.env.FZF_DEFAULT_OPTS = ''
  end,
  opts = {
    -- ファイル名を先に、パスを後ろに薄く表示する。
    -- Next.js のように page.tsx が大量にある構成では、これが無いと判別できない
    --
    -- fzf-lua は rg を起動する時 RIPGREP_CONFIG_PATH を空にする（fzf.lua:159）。
    -- そのままだと ~/.config/ripgrep/config の --hidden が効かず、dotfiles のように
    -- packages/<tool>/.config/... と隠しディレクトリを含む構成が丸ごと検索から漏れる。
    -- opts の直下に書いても provider には伝わらないため grep の中に置く。
    -- fd は rg の設定を読まないので、files 側は --hidden を直接足す
    files = {
      formatter = 'path.filename_first',
      fd_opts = '--color=never --type f --type l --hidden --exclude .git --exclude .jj',
    },
    grep = {
      formatter = 'path.filename_first',
      RIPGREP_CONFIG_PATH = vim.env.RIPGREP_CONFIG_PATH,
    },
    oldfiles = { formatter = 'path.filename_first', include_current_session = true },
    -- 既に窓に出ているバッファは、そこへ飛ぶ。同じファイルを2枚開かずに済む。
    --
    -- 差分を映している窓は飛び先にしない。codediff のペインは実ファイルの
    -- バッファをそのまま表示しているため、編集するつもりで選んだのに
    -- 差分の片側へ入ってしまう。
    --
    -- codediff は nvim の差分モードを使わず自前で描くので、
    -- vim.wo.diff では判定できない。タブに codediff のバッファが
    -- 1つでもあれば、そのタブごと飛び先から外す。
    -- :DiffDisk の差分は差分モードなので wo.diff で拾える。
    --
    -- 今いるタブを先に見る。同じタブに出ているなら動かずに済む
    buffers = {
      formatter = 'path.filename_first',
      actions = {
        ['default'] = function(selected, opts)
          local entry = require('fzf-lua.path').entry_to_file(selected[1], opts)
          -- bufnr が入らない形で来ることがあるのでパスからも引く
          local bufnr = entry.bufnr
          if not bufnr and entry.path then
            local found = vim.fn.bufnr(vim.fn.fnamemodify(entry.path, ':p'))
            bufnr = found >= 0 and found or nil
          end
          if bufnr then
            local function shows_codediff(tab)
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
                if ft:match('^codediff') then
                  return true
                end
              end
              return false
            end

            -- 今いるタブを先頭に並べ替える
            local tabs = { vim.api.nvim_get_current_tabpage() }
            for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
              if tab ~= tabs[1] then
                tabs[#tabs + 1] = tab
              end
            end

            for _, tab in ipairs(tabs) do
              if not shows_codediff(tab) then
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                  if vim.api.nvim_win_get_buf(win) == bufnr and not vim.wo[win].diff then
                    vim.api.nvim_set_current_tabpage(tab)
                    vim.api.nvim_set_current_win(win)
                    return
                  end
                end
              end
            end
          end
          -- どの窓にも出ていなければ今まで通り開く
          require('fzf-lua.actions').file_edit(selected, opts)
        end,
      },
    },
    -- f/ と / のバッファ内検索だけプレビューを畳む。今開いているファイルなので
    -- 候補行の周りは画面にそのまま見えている。
    --
    -- previewer = false ではなく hidden にしているのは、こちらは窓を隠すだけで
    -- <F4> でその場に出せるため（previewer = false はトグルごと殺す）
    blines = { winopts = { preview = { hidden = true } } },
    winopts = {
      height = 0.85,
      width = 0.85,
      preview = { layout = 'flex', scrollbar = 'float' },
    },
    -- Alt-i（.gitignore を無視して検索し直す）をヘッダーに出す。
    --
    -- node_modules を既定で外すのは正しい。自分が書いた行が埋もれるため。
    -- 一方で依存ライブラリの中を追う時だけは外したい。
    -- fzf-lua は割り当てだけ用意してヘッダーから隠している（defaults.lua:262）。
    -- 表示が無いと存在を思い出せない。
    --
    -- 文言を自前の関数にするのは、live_grep で状態を正しく読むため。
    -- fzf-lua 内蔵の文言は cmd 文字列を見る。live_grep はこの時点で cmd を持たない。
    --
    -- bind テーブルは既定と併合されない。先頭の true で引き継ぎを指定する。
    -- fn と reuse は既定から補われる。
    -- Alt-h（hidden）と Alt-f（symlink）は隠したまま残す
    actions = {
      files = {
        true,
        ['alt-i'] = {
          header = function(o)
            return o.no_ignore and 'Respect .gitignore' or 'Disable .gitignore'
          end,
        },
      },
    },
    keymap = {
      builtin = {
        ['<C-d>'] = 'preview-page-down',
        ['<C-u>'] = 'preview-page-up',
        ['<C-/>'] = 'toggle-help',
      },
      fzf = {
        ['ctrl-d'] = 'preview-page-down',
        ['ctrl-u'] = 'preview-page-up',
        -- 検索結果をまとめて quickfix に送る
        ['ctrl-q'] = 'select-all+accept',
      },
    },
  },
}
