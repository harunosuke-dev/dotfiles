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
        -- NOTE: TODO は検索の件数（NoiceVirtualText）と同じ magenta300 になる。
        -- 出る場所が違うので取り違えない
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

  -- TypeScript のエラーメッセージを平易な文に置き換える。
  {
    'dmmulroy/ts-error-translator.nvim',
    ft = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
    opts = {},
  },
}
