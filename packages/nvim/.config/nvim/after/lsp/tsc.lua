-- TS 7 の tsc 自身が言語サーバになる（tsc --lsp --stdio）。
-- nvim-lspconfig の lsp/tsc.lua は、プロジェクトの node_modules/.bin/tsc が 7 以上のときだけ付く。
-- TS 6 以下のプロジェクトは vtsls が受け持つ（after/lsp/vtsls.lua の root_dir）
return {
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
