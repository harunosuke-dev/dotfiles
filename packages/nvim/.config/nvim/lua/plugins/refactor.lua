return {
  -- package.json を開くと各依存の最新版を行末に表示し、その場で更新できる
  {
    'vuki656/package-info.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    ft = 'json',
    opts = {
      hide_up_to_date = true, -- 最新のものは表示しない（更新が必要なものだけ目立たせる）
      package_manager = 'npm',
    },
    keys = {
      -- <leader>n は通知（noice）が使うため、npm 関連は <leader>sn 配下に置く。
      --
      -- 行末への表示は autostart（既定で有効）が package.json を開いた時に
      -- 自動で行う。sns はそれを手動で出し直すためのもの。
      -- バージョンを選んで変える change_version は張らない。使う場面が稀で、
      -- 番号を直接書き換えて npm install した方が結果が見える
      {
        '<leader>sns',
        function()
          require('package-info').show({ force = true })
        end,
        desc = 'Show npm dependency versions',
      },
      {
        '<leader>snu',
        function()
          require('package-info').update()
        end,
        desc = 'Update dependency on this line',
      },
    },
  },
}
