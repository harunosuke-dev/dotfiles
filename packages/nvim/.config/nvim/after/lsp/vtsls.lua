-- 型の推論結果を行内に薄く表示する設定。<leader>uh で表示/非表示を切り替えられる
local inlay_hints = {
  parameterNames = { enabled = 'literals' }, -- foo(true) の "true" が何の引数かを表示
  parameterTypes = { enabled = true },
  variableTypes = { enabled = false }, -- 変数の型まで出すと行が煩雑になるので off
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

-- プロジェクトの TypeScript の major を返す。入っていなければ nil
local function typescript_major(root)
  local path = vim.fs.joinpath(root, 'node_modules/typescript/package.json')
  if not vim.uv.fs_stat(path) then
    return nil
  end
  local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  if not ok or type(pkg.version) ~= 'string' then
    return nil
  end
  local version = vim.version.parse(pkg.version)
  return version and version.major
end

return {
  -- TS 7 のプロジェクトでは付かない。
  -- vtsls はプロジェクトの tsserver を使うが、TS 7 には無く、vtsls 同梱の TS で型を見てしまう。
  -- TS 7 では、TS 7 の tsc 自身が言語サーバになるので、そちら（lsp/tsc.lua）に任せる。
  -- NOTE: nvim-lspconfig の root_dir を丸ごと置き換えている。deno を除く判定は省いた（deno を使っていないため）
  root_dir = function(bufnr, on_dir)
    local markers = { { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock' }, { '.git' } }
    local root = vim.fs.root(bufnr, markers) or vim.fn.getcwd()
    local major = typescript_major(root)
    if major and major >= 7 then
      return
    end
    on_dir(root)
  end,
  settings = {
    typescript = {
      inlayHints = inlay_hints,
      updateImportsOnFileMove = { enabled = 'always' }, -- ファイル移動時に import を自動修正
      -- tsconfig の paths（Next.js の "@/*"）を優先して import を書く
      preferences = { importModuleSpecifier = 'non-relative' },
    },
    javascript = {
      inlayHints = inlay_hints,
      updateImportsOnFileMove = { enabled = 'always' },
    },
    vtsls = {
      autoUseWorkspaceTsdk = true, -- プロジェクトの node_modules の TypeScript を使う
      experimental = {
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
  },
}
