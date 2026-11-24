-- TS 7 の tsc 自身が言語サーバになる（tsc --lsp --stdio）。
-- nvim-lspconfig の lsp/tsc.lua は、プロジェクトの node_modules/.bin/tsc が 7 以上のときだけ付く。
-- TS 6 以下のプロジェクトは vtsls が受け持つ（after/lsp/vtsls.lua の root_dir）
return {
  -- HACK: TS 7.0.2 の tsc は documentHighlight に、いつも空の結果を返す（references は返す。2026-10-28 に確かめた）。
  -- vim-illuminate は lsp を先に使うので、カーソル下の単語が光らない。
  -- treesitter に落とすと、名前が同じだけの別の変数（別のスコープの post など）まで光る。
  -- そこで documentHighlight の要求を references に差し替え、このファイルの中の参照だけを返す。
  -- tsc が documentHighlight を返すようになったら外す
  on_init = function(client)
    local request = client.request
    client.request = function(self, method, params, handler, bufnr)
      if method ~= 'textDocument/documentHighlight' or handler == nil then
        return request(self, method, params, handler, bufnr)
      end
      local references_params = vim.tbl_extend('force', params, { context = { includeDeclaration = true } })
      return request(self, 'textDocument/references', references_params, function(err, result, ctx)
        -- URI の書き方（[ ] を %5B %5D にするか）が Neovim と tsc で違うので、ファイル名に直して比べる
        local fname = vim.uri_to_fname(params.textDocument.uri)
        local highlights = {}
        for _, location in ipairs(result or {}) do
          if vim.uri_to_fname(location.uri) == fname then
            table.insert(highlights, { range = location.range, kind = 1 }) -- 1 = Text
          end
        end
        handler(err, highlights, vim.tbl_extend('force', ctx, { method = method }))
      end, bufnr)
    end
  end,
  settings = {
    -- 設定の名前は vtsls（typescript.*）と違い、js/ts にまとまっている
    ['js/ts'] = {
      inlayHints = {
        parameterNames = { enabled = 'literals' },
        variableTypes = { enabled = false }, -- vtsls と同じく、変数の型まで出すと行が煩雑になるので off
      },
    },
  },
}
