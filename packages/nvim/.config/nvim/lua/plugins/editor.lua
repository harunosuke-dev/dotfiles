return {
  -- カーソル下の単語と同じものを画面内で薄くハイライトする。
  -- LSP が使える場面では「同じ綴りの別物」を除いた正確な参照だけを光らせる
  {
    'RRethy/vim-illuminate',
    event = { 'BufReadPost', 'BufNewFile' },
    -- 移動用のキーマップ（]] / [[ で同じ識別子へ）は張らない。
    -- 素の Vim ではセクション移動に割り当てられており、基本方針として標準は潰さない。
    -- このプラグインの主目的である「同じ識別子を薄く光らせる」表示だけを使う
    config = function()
      require('illuminate').configure({
        delay = 200,
        -- 上から順に試し、使えるものを採用する。
        -- lsp = 意味を理解した参照、treesitter = 構文上の同一シンボル、regex = 単純な文字列一致
        providers = { 'lsp', 'treesitter', 'regex' },
        filetypes_denylist = {
          'oil',
          'trouble',
          'lazy',
          'mason',
          'help',
          'checkhealth',
          'fzf',
          'gitcommit',
        },
        large_file_cutoff = 2000, -- 行数がこれを超えたら regex 版を使わない
      })

      -- 既定は下線だが、診断の警告表示にも下線を使っているため区別がつかない。
      -- 背景色の帯に変える。
      --
      -- 帯の色はテーマの定義をそのまま使う。本文との差はテーマ作者が決めている。
      -- 以前は Visual を 1.7 倍に持ち上げて自前で作っていたが、
      -- catppuccin のように作者が暗くしているテーマでは向きが逆になり、
      -- 帯が白っぽく浮いていた。
      --
      -- 定義を持たないテーマ（iceberg）にだけ補う。色は solarized-osaka から借りて、
      -- incline の配色と出どころを揃える。
      --
      -- 文字色は常に明示する。背景だけのグループだと、colorizer が色コードへ
      -- 付けた文字色（明るい色ほど黒くなる）が残り、黒背景に黒文字で読めなくなる
      local FALLBACK = {
        IlluminatedWordText = 'violet900',
        IlluminatedWordRead = 'magenta900',
        IlluminatedWordWrite = 'magenta900',
      }

      local function set_hl()
        local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
        local ok, palette = pcall(require, 'solarized-osaka.colors')
        local colors = ok and palette.setup() or {}
        for group, key in pairs(FALLBACK) do
          local theme = vim.api.nvim_get_hl(0, { name = group, link = false })
          vim.api.nvim_set_hl(0, group, { bg = theme.bg or colors[key], fg = normal.fg })
        end
      end

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('user_illuminate_hl', { clear = true }),
        callback = set_hl,
      })
      set_hl()
    end,
  },

  -- 括弧・引用符の自動補完。check_ts で構文木を見るため、
  -- 文字列やコメントの中では余計な補完をしない
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {
      check_ts = true,
      fast_wrap = {}, -- 挿入モードで <M-e> を押すと、カーソル後方の語を括弧で包む
    },
  },

  -- 囲み文字の操作。sa=追加 / sd=削除 / sr=置換 / sf=端へ飛ぶ / sh=光らせる
  -- 例: saiw) で単語を () で囲む、sr"' で "..." を '...' に変える、sd" で外す
  --
  -- vim-surround 系（nvim-surround の ys / cs / ds）から乗り換えた。
  -- ys の y は「you surround」の語呂で、yank とは無関係。読み違えやすい。
  -- こちらは surround add / replace / delete がそのまま語になっている。
  --
  -- 前置が s なので、素の Vim の s（1文字消して挿入）は単独で押すと
  -- timeoutlen ぶん待ってから動く。消えるわけではない。
  -- この設定は timeoutlen = 150 なので遅延は 0.15 秒（実測で確認済み）。
  --
  -- mini.ai と同じ n（次）/ l（前）の修飾子が使えるのも揃っていて良い
  {
    'echasnovski/mini.surround',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      n_lines = 500, -- mini.ai と揃える。対象を探す範囲
      -- 探索は既定の 'cover'（カーソルを覆っている囲みだけ）。外にいる時は
      -- n / l を挟んで向きを指定する（sdn" で次、sdl" で前）。
      -- 打鍵を減らしたくなったら下を有効にする。覆っていない時に前方を探すので
      -- n を省ける。代わりにどこが対象か目で確かめずに打つことになる
      -- search_method = 'cover_or_next',
    },
  },

  -- 括弧・引用符のテキストオブジェクトを賢くする。
  --
  -- 関数・クラス・引数（af if ac ic aa ia）は nvim-treesitter-textobjects が
  -- 持っており、そちらが優先される（Vim は長い方の割り当てを選ぶため、
  -- af は treesitter、a( は mini.ai に渡る）。
  --
  -- mini.ai が足すのは素の Vim より賢い括弧・引用符の扱い。
  --   ci(  カーソルが括弧の手前にあっても、次の括弧の中を対象にする
  --   ci"  複数行にまたがる文字列でも効く
  --   2i(  2つ外側の括弧の中
  {
    'echasnovski/mini.ai',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      n_lines = 500, -- 対象を探す範囲。大きなファイルでも関数全体を拾える
    },
  },
}
