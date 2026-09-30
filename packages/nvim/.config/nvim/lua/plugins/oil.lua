-- oil.nvim はディレクトリを「編集可能なバッファ」として開くファイラ。
-- 行を書き換えてリネーム、行を消して削除、行を足して新規作成し、:w で確定する。
-- 通常の Vim 操作（dd / p / cw / ビジュアル選択）がそのまま使えるのが利点
--- 引数なしで開いた時に、その場に git の変更が残っているか。
--- 残っていれば「何をしていたか」の答えなので、差分のレビューから始める
local function has_changes()
  if vim.fn.argc(-1) > 0 or vim.fn.executable('git') == 0 then
    return false
  end
  local changed = vim.fn.systemlist({ 'git', 'status', '--porcelain' })
  return vim.v.shell_error == 0 and #changed > 0
end

return {
  'stevearc/oil.nvim',
  -- netrw を置き換えるため遅延ロードしない（起動直後に nvim . で開けるように）
  lazy = false,
  -- 引数なしで開いた時の画面。起動画面は持たない（lua/plugins/snacks.lua の注記）。
  --
  -- git に変更が残っていれば差分のレビューから始める。「何をしていたか」の答えが
  -- そこにあるため。残っていなければファイラから始める。開くのはどちらか一方。
  -- codediff を閉じた後にファイラを出すのは lua/plugins/git.lua の側。
  --
  -- VimEnter を待つのは codediff が cmd で遅延ロードされるため
  init = function()
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        if vim.fn.argc(-1) > 0 then
          return
        end
        local review = has_changes()
        vim.schedule(function()
          if not review then
            pcall(vim.cmd, 'Oil')
            return
          end
          -- codediff は必ず tabnew する（ui/view/side_by_side.lua の create）。
          -- そのままだと起動時の空タブが1枚目に残るので、
          -- 作られたタブへ入った時点で空の方を閉じる
          local start_tab = vim.api.nvim_get_current_tabpage()
          local start_buf = vim.api.nvim_get_current_buf()
          local id = vim.api.nvim_create_autocmd('TabNewEntered', {
            once = true,
            callback = function()
              vim.schedule(function()
                if vim.api.nvim_tabpage_is_valid(start_tab) then
                  pcall(vim.cmd, vim.api.nvim_tabpage_get_number(start_tab) .. 'tabclose')
                end
                -- タブを閉じてもバッファは一覧に残る。無名のまま残ると
                -- ]b や <Space>fb に空の行が混ざるので捨てる
                if vim.api.nvim_buf_is_valid(start_buf) and vim.api.nvim_buf_get_name(start_buf) == '' then
                  pcall(vim.api.nvim_buf_delete, start_buf, {})
                end
              end)
            end,
          })
          if not pcall(vim.cmd, 'CodeDiff') then
            pcall(vim.api.nvim_del_autocmd, id)
          end
        end)
      end,
    })
  end,
  keys = {
    -- oil の定番は - だが、素の Vim では「前の行の先頭へ」という移動キー。
    -- <leader>e と同じ動作を2箇所に置いても得るものが無いので、こちらだけ残す
    { '<leader>e', '<cmd>Oil<cr>', desc = 'Open the file explorer' },
  },
  opts = {
    default_file_explorer = true,
    -- 外部でファイルが増減・改名された時に一覧を追従させる。
    -- 開いているディレクトリごとに fs_event を張る（oil/view.lua）。
    -- 編集中（modified）や oil 自身の操作中は触らないので、入力は壊れない
    watch_for_changes = true,
    delete_to_trash = true, -- 削除は :w 時にゴミ箱へ（復元可能）
    skip_confirm_for_simple_edits = false, -- 変更内容の確認は必ず出す
    view_options = {
      show_hidden = true, -- .env や .github を隠さない
    },
    win_options = {
      -- git の状態を出す列。gitsigns は oil のバッファ（oil:// という実ファイルで
      -- ない名前）に attach しないので、lua/config/oil-git.lua が自分で置く
      signcolumn = 'yes:2',
    },
    keymaps = {
      ['g?'] = 'actions.show_help',
      ['<CR>'] = 'actions.select',
      ['<C-s>'] = { 'actions.select', opts = { vertical = true } },
      ['<C-h>'] = false, -- ウィンドウ移動を優先するため無効化
      -- <C-t>（タブで開く）は張らない。タブページを使わない構成で、gT も
      -- 型定義ジャンプに充てているため
      ['<C-p>'] = 'actions.preview',
      ['<C-c>'] = 'actions.close',
      ['<C-l>'] = false, -- 同上（更新は <C-r> を使う）
      ['<C-r>'] = 'actions.refresh',
      ['-'] = 'actions.parent',
      ['_'] = 'actions.open_cwd',
      ['`'] = 'actions.cd',
      ['gs'] = 'actions.change_sort',
      ['gx'] = 'actions.open_external',
      ['g.'] = 'actions.toggle_hidden',
    },
    use_default_keymaps = false, -- 上の定義だけを使う（既定との二重定義を避ける）
  },
  config = function(_, opts)
    require('oil').setup(opts)
    -- 変更のあるファイルを符号列で示す。oil の公開 API（get_entry_on_line と
    -- User OilEnter）だけで動くので、oil 側の設定には手を入れない
    require('config.oil-git').setup()
  end,
}
