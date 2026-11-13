return {
  -- TODO: to-do を書きます
  -- NOTE: note を書きます
  -- WARNING : warning を書きます
  -- FIXME: bug を明示しておきます
  -- HACK: 常套手段でない方法で直しています
  -- TEST: test を書きます
  --
  --コメントに色と記号を付け、一覧・ジャンプできるようにする
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    -- opts をテーブルで書くと起動時に評価される。その時点では
    -- solarized-osaka を読めないため、関数にして読み込み時まで遅らせる
    opts = function()
      local c = require('solarized-osaka.colors').setup()
      return {
        signs = true,
        -- TEST の既定の記号は U+23F2（⏲）で、Nerd Font ではなく素の Unicode。
        -- ターミナルのフォント（UDEV Gothic 35NF）に入っておらず、
        -- OS のフォールバックで描かれるため幅と字形が他と揃わない。
        -- フラスコ（nf-fa-flask）に替える。TODO や WARN と同じ Font Awesome 系
        keywords = {
          TEST = { icon = ' ' },
        },
        -- 色は solarized-osaka のパレットから取る。診断とも本文とも別の段
        -- （300 番台）を使い、コメントの中で埋もれないようにする。
        -- error だけ既定で DiagnosticError を見るため、ここで明示して切り離す。
        --
        -- NOTE: TODO は検索の件数と同じ magenta300 になる。
        -- 件数はステータスラインに出るので取り違えない
        colors = {
          info = { c.magenta300 }, -- TODO
          hint = { c.cyan300 }, -- NOTE, INFO
          warning = { c.yellow300 }, -- HACK, WARN, WARNING, XXX
          error = { c.red300 }, -- FIX, FIXME, BUG, FIXIT, ISSUE
          -- TEST の枠は既定で Identifier を見る。iceberg はそこを Normal と
          -- 同値にしているため、本文に埋もれて印にならない。
          -- 成否を扱うタグなので真緑を当てる。パレットの外から取った固定値。
          -- solarized の green は黄緑で HACK と 31 度しか離れず、
          -- Added の緑は彩度が低くて印として弱い
          test = { '#35da60' }, -- TEST, TESTING, PASSED, FAILED
        },
      }
    end,
    keys = {
      { '<leader>ft', '<cmd>TodoFzfLua<cr>', desc = '[F]ind [T]odo in this project' },
      {
        ']t',
        function()
          require('todo-comments').jump_next()
        end,
        desc = 'Next TODO comment',
      },
      {
        '[t',
        function()
          require('todo-comments').jump_prev()
        end,
        desc = 'Prev TODO comment',
      },
    },
  },

  -- quickfix の一覧に色を付ける。
  --
  -- nvim の syntax/qf.vim は本文に色を指定していない。grep の結果は1行の大半が
  -- 本文なので、ほぼ白一色になる。行ごとに元のファイルの言語が違うため、
  -- 構文ファイルの上書きでは解けない。
  --
  -- 窓は quickfix のままなので、j / k の追従も q も ]q も今の設定が効く。
  --
  -- 一覧をそのまま編集して元のファイルへ反映できる。素の quickfix は
  -- nomodifiable で、直すには <CR> で本文へ飛ぶ必要がある。
  --
  -- 書き戻す先はバッファで、ディスクには触らない（autosave = false）。
  -- 反映を見てから自分で保存する。行ごとに「記録時と同じ中身か」を照合し、
  -- 違えばその行だけ拒んで理由を一覧に差し込む。
  --
  -- 一括置換そのものは :cdo でもできる。
  -- ここの取り柄は、今見ている一覧を行ごとに不揃いに直せること
  {
    'stevearc/quicker.nvim',
    ft = 'qf',
    opts = {
      edit = { enabled = true, autosave = false },
      -- 追従は lua/config/autocmds.lua の CursorMoved で既に作ってある
      follow = { enabled = false },
      highlight = {
        treesitter = true,
        lsp = true,
        -- 一覧に出たファイルをバッファへ読み込んでから色を付ける。
        -- 読み込まないと1行だけを切り出して解析するため、文脈が要る色が落ちる。
        -- LSP のセマンティックトークンも読み込み済みのバッファからしか取れない
        load_buffers = true,
      },
    },
  },

  -- 診断・シンボル・検索結果を、閉じずに置いておける一覧として表示する。
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    opts = {
      focus = true, -- 開いたらそのウィンドウにカーソルを移す
    },
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics list in project' },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Diagnostics list in this file',
      },
      {
        '<leader>xs',
        '<cmd>Trouble symbols toggle win.position=right<cr>',
        desc = 'Symbol tree on the right',
      },
      { '<leader>xl', '<cmd>Trouble lsp toggle win.position=right<cr>', desc = 'LSP defs and refs on the right' },
      { '<leader>xt', '<cmd>Trouble todo toggle<cr>', desc = 'TODO list, keep it open' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix list in trouble' },
    },
  },
}
