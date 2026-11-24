-- Markdown のプレビュー。ブラウザに整形済みの文書を出し、入力とスクロールを同期する。
--
-- バッファの中で装飾する方式（render-markdown）はやめた。画像・数式・Mermaid が
-- 出ないため、書いたものの最終形を確かめられない。
return {
  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown', 'mdx' },
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    -- 公式は `cd app && yarn install` だが yarn を入れていない。
    -- 同梱の取得関数はビルド済みのものを落としてくるので npm も要らない。
    --
    -- WARNING: 遅延読み込みのため、build が走る時点では autoload が未登録。
    -- 先に読み込ませないと mkdp#util#install が見つからない
    build = function(plugin)
      require('lazy').load({ plugins = { plugin.name } })
      vim.fn['mkdp#util#install']()
    end,
    init = function()
      -- mdx も markdown として扱う。拡張子の対応は filetype.lua 側で済んでいる
      vim.g.mkdp_filetypes = { 'markdown', 'mdx' }

      -- 開くのは手で押した時だけ。markdown を開くたびにブラウザが出ると邪魔になる
      vim.g.mkdp_auto_start = 0
      -- 別のファイルへ移った時に閉じる。開いたままだと中身が前のファイルのまま残る
      vim.g.mkdp_auto_close = 1
      -- 配色は nvim 側と揃える。背景を透過させている都合で dark に固定している
      vim.g.mkdp_theme = 'dark'

      -- Chrome を新しいウィンドウで開く。
      --
      -- mkdp_browser はコマンド名だけを受ける指定で、--new-window のような
      -- 引数を渡せない。関数を渡せば自分で組み立てられる。
      --
      -- WARNING: Lua の関数は渡せない。プラグインは RPC で
      -- nvim_call_function(名前, [url]) を呼ぶため（app/server.js:157）、
      -- v:lua.Foo の形は関数名として解決されず E117 になる。
      --
      -- open の -n は「起動済みでも新しいインスタンスを開く」、
      -- --args 以降は Chrome 自身に渡る（macOS の open の仕様）
      vim.cmd([[
        function! MkdpOpenInChrome(url) abort
          call jobstart(['open', '-na', 'Google Chrome', '--args', '--new-window', a:url])
        endfunction
      ]])

      vim.g.mkdp_browserfunc = 'MkdpOpenInChrome'
    end,
    keys = {
      {
        '<leader>mp',
        '<cmd>MarkdownPreviewToggle<cr>',
        ft = { 'markdown', 'mdx' },
        desc = '[M]arkdown [P]review in Chrome',
      },
    },
  },
}
