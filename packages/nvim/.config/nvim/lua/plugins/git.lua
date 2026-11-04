return {
  -- コミット・ステージング・履歴閲覧など、腰を据えた git 操作は lazygit に任せる
  {
    'kdheepak/lazygit.nvim',
    cmd = { 'LazyGit', 'LazyGitCurrentFile', 'LazyGitFilter', 'LazyGitFilterCurrentFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      -- 直接 :LazyGit を呼ばず、起動した窓を覚える包みを通す。
      -- lazygit の中で e を押した時に、その窓へファイルを返すため
      -- （lua/config/lazygit.lua）
      {
        '<leader>gg',
        function()
          require('config.lazygit').open()
        end,
        desc = 'Open lazygit',
      },
    },
  },

  -- 編集中に見える範囲の差分表示と、hunk 単位の細かい操作は gitsigns が担当する
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '│' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      current_line_blame = false, -- 常時表示はうるさいので <leader>hb で都度出す
      on_attach = function(bufnr)
        -- gitsigns はステージ済み変更用のハイライトを接続後（非同期）に定義するため、
        -- カラースキーム側のイベントでは取りこぼす。ここから当て直す
        require('config.highlights').apply()

        local gs = require('gitsigns')
        local function map(mode, key, fn, desc)
          vim.keymap.set(mode, key, fn, { buffer = bufnr, desc = 'Git: ' .. desc })
        end

        -- ステージングは張らない。コミットを組み立てる作業は lazygit（<leader>gg）に
        -- 任せる方が、全ファイルを見渡しながら選べて速い。
        -- ここに残すのは「今開いているバッファのカーソル位置」に紐づくものだけ。
        -- その文脈は lazygit へ移った時点で失われるため、代替が効かない

        -- 変更箇所（hunk）の移動。差分モード中は標準の ]c / [c に委ねる
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal({ ']c', bang = true })
          else
            gs.nav_hunk('next')
          end
        end, 'Next change')
        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal({ '[c', bang = true })
          else
            gs.nav_hunk('prev')
          end
        end, 'Prev change')

        -- 取り消し。u で戻れない状況（保存後や他の編集を挟んだ後）の救済として残す。
        -- ビジュアル選択中は選んだ行だけが対象になる
        map('n', '<leader>hr', gs.reset_hunk, '[H]unk [R]eset : discard changes')
        map('x', '<leader>hr', function()
          gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
        end, '[H]unk [R]eset on selected lines')

        -- 確認系
        map('n', '<leader>hp', gs.preview_hunk, '[H]unk [P]review')
        map('n', '<leader>hb', function()
          gs.blame_line({ full = true })
        end, '[H]unk [B]lame : commit for line')
        -- 1ファイルに絞った差分。gitsigns の diffthis ではなく codediff で開く。
        --
        -- diffthis は縦分割でインデックス側のバッファを開くが、閉じる順番を誤ると
        -- 落ちる（差分モードのまま窓を解放すると、幅の再計算で DiffUpdated が飛び、
        -- 壊れかけのウィンドウ一覧を辿って SIGSEGV）。その回避に30行以上使っていた。
        --
        -- codediff なら <Space>gc と同じ見た目で、タブごと閉じれば済む。
        -- % は codediff が展開しないので、パスは自分で渡す
        local function file_diff(revision)
          return function()
            local file = vim.api.nvim_buf_get_name(0)
            if file == '' then
              vim.notify('名前の付いたファイルでのみ使える', vim.log.levels.WARN)
              return
            end
            local cmd = 'CodeDiff ' .. (revision and revision .. ' ' or '') .. '-- ' .. vim.fn.fnameescape(file)
            require('config.codediff').open('file-diff', cmd, (revision or '') .. file)
          end
        end

        map('n', '<leader>hd', file_diff(), '[H]unk [D]iff of this file')
        map('n', '<leader>hD', file_diff('HEAD~'), '[H]unk [D]iff of this file against HEAD~')

        -- 表示の切り替え
        map('n', '<leader>ub', gs.toggle_current_line_blame, '[U]I [B]lame : toggle inline')

        -- テキストオブジェクト。dih で変更箇所を丸ごと捨てる、といった操作ができる
        vim.keymap.set({ 'o', 'x' }, 'ih', gs.select_hunk, { buffer = bufnr, desc = 'Git: [i]nner [h]unk' })
      end,
    },
  },

  -- 変更のあったファイルを左のパネルに並べ、選ぶと横並びの差分を開く。
  -- <leader>hd（gitsigns の diffthis）が1ファイルを見る道具なのに対し、
  -- こちらはブランチ単位で全部見て回る道具。
  --
  -- :CodeDiff main... がマージベースとの差分（PR と同じ範囲）を出す。
  -- :CodeDiff v1 v2 -- packages/ui のようにパスも絞れる。今の手持ちに無いのはここ
  {
    'esmuellert/codediff.nvim',
    cmd = 'CodeDiff', -- :CodeDiff を打つまで読み込まない
    opts = {
      -- 色は <leader>hd と同じものを使う。lua/config/highlights.lua が
      -- テーマに依らず定義しているグループを指す。
      -- 名前で渡すと文字色まで引き継がれる（ui/highlights.lua の
      -- resolve_char_highlight）ので、変わった文字を白く浮かせる指定も効く。
      --
      -- 素の :diffthis と違い、こちらは追加と削除を自分で区別する。
      -- 左右へ振り分ける必要がないので Old / New をそのまま当てられる
      highlights = {
        line_insert = 'DiffAddNew',
        line_delete = 'DiffChangeOld',
        char_insert = 'DiffTextNew',
        char_delete = 'DiffTextOld',
      },
      explorer = {
        view_mode = 'tree', -- 既定は平坦な一覧
        -- j/k で移動するだけで差分が切り替わる。一覧に留まったまま見て回れる
        auto_open_on_cursor = true,
      },
    },
    config = function(_, opts)
      require('codediff').setup(opts)
      -- 自前のハイライトを setup 時に定義するため、こちらから当て直す
      require('config.highlights').diff()

      -- 差分を開くと、以後に作る窓から行番号などが消える問題への対処。
      --
      -- explorer は nui の split で、number や signcolumn を切って作られる
      -- （ui/explorer/render.lua）。窓ローカルのつもりの指定だが、Neovim では
      -- 窓ローカル項目を当てると大域の既定まで書き換わる。
      -- 新しい窓は「今いる窓」ではなく大域から値を引くため、影響が全体へ及ぶ。
      --
      -- 読み込み直後（まだ差分を開いていない時点）の値を控え、開いた後に戻す
      local WINDOW_DEFAULTS = { 'number', 'relativenumber', 'signcolumn', 'wrap', 'list', 'foldcolumn', 'spell' }
      local defaults = {}
      for _, name in ipairs(WINDOW_DEFAULTS) do
        defaults[name] = vim.go[name]
      end

      vim.api.nvim_create_autocmd('User', {
        pattern = 'CodeDiffOpen',
        group = vim.api.nvim_create_augroup('user_codediff_window_defaults', { clear = true }),
        callback = function()
          vim.schedule(function()
            for name, value in pairs(defaults) do
              vim.go[name] = value
            end
          end)
        end,
      })

      -- gf（open_in_prev_tab）は「1つ左のタブで開く」。差分を左端に置くと
      -- 左が無いので、新しいタブが左端に差し込まれて差分が押し出される。
      -- 呼び出しの前後でタブを入れ替え、右隣で開く形に反転させる。
      -- ファイルの解決や仮想バッファの扱いは本来の実装をそのまま使う。
      --
      -- WARNING: プラグインの内部関数を包んでいる。名前や引数が変われば効かなくなる。
      -- その時は gf が元の「左で開く」に戻るだけで、壊れはしない
      local panes = require('codediff.ui.view.actions.panes')
      local open_in_prev_tab = panes.open_in_prev_tab
      panes.open_in_prev_tab = function(ctx)
        local diff_tab = vim.api.nvim_get_current_tabpage()
        if #vim.api.nvim_list_tabpages() > 1 then
          pcall(vim.cmd, 'tabmove +1')
        end
        open_in_prev_tab(ctx)
        -- 差分を左端へ戻す。開いたファイルの側にフォーカスを残す
        local opened = vim.api.nvim_get_current_tabpage()
        if vim.api.nvim_tabpage_is_valid(diff_tab) and diff_tab ~= opened then
          vim.api.nvim_set_current_tabpage(diff_tab)
          pcall(vim.cmd, 'tabmove 0')
          if vim.api.nvim_tabpage_is_valid(opened) then
            vim.api.nvim_set_current_tabpage(opened)
          end
        end
        require('config.codediff').wipe_blank_buffers()
      end
    end,
    keys = {
      -- 入口ごとにタブを1枚だけ持つ（lua/config/codediff.lua）。
      -- 同じキーを押し直した時は、組み直さずそのタブへ飛ぶ
      {
        '<leader>gc',
        function()
          require('config.codediff').open('changes', 'CodeDiff')
        end,
        desc = '[G]it [C]hanges : review the tree',
      },
      {
        '<leader>gp',
        function()
          -- 派生元との差分（PR と同じ範囲）。基準は origin/HEAD から引く。
          -- main 直書きだと master のリポジトリで外れる
          local base = vim.fn.systemlist({ 'git', 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD' })[1]
          base = base and base:gsub('^refs/remotes/', '') or 'origin/main'
          require('config.codediff').open('pr', 'CodeDiff ' .. base .. '...')
        end,
        desc = '[G]it [P]R : changes since branching',
      },
      -- ファイル単体の履歴。対象が変わればタブを開き直す
      {
        '<leader>gh',
        function()
          local file = vim.api.nvim_buf_get_name(0)
          if file == '' then
            vim.notify('名前の付いたファイルでのみ使える', vim.log.levels.WARN)
            return
          end
          require('config.codediff').open('file-history', 'CodeDiff history %', file)
        end,
        desc = '[G]it [H]istory of this file',
      },
      {
        '<leader>gH',
        function()
          require('config.codediff').open('history', 'CodeDiff history')
        end,
        desc = '[G]it [H]istory of the repo',
      },
      -- コンフリクトの3方向マージ。必ず起きる作業なのに入口が無かった
      {
        '<leader>gm',
        function()
          local file = vim.api.nvim_buf_get_name(0)
          if file == '' then
            vim.notify('名前の付いたファイルでのみ使える', vim.log.levels.WARN)
            return
          end
          require('config.codediff').open('merge', 'CodeDiff merge ' .. vim.fn.fnameescape(file), file)
        end,
        desc = '[G]it [M]erge : resolve conflicts in this file',
      },
      {
        '<leader>gh',
        ':CodeDiff history<cr>',
        mode = 'x',
        desc = '[G]it [H]istory for the selected lines',
      },
    },
  },
}
