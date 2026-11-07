-- リーダーキーは何よりも先に定義する
-- （プラグイン読み込み後に定義すると、既に登録済みのマップが古い値のままになる）
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 組み込みのメッセージ UI（vim._core.ui2）を使う。
--
-- このブランチは noice を外せるかを見るためのもので、既定で有効にしてある。
-- noice と見比べる時だけ NVIM_UI2=0 nvim で起動する。
-- プラグインの spec から見えるよう、lazy より前に決める
vim.g.core_ui2 = vim.env.NVIM_UI2 ~= '0'

require('config.options')
require('config.filetype')
require('config.keymaps')
require('config.autocmds')
require('config.commands')
require('config.snippets').setup()
require('config.practice').setup()
require('config.zoom').setup()
require('config.next_docs').setup()
require('config.codediff').setup()
require('config.core-ui2').setup()
require('config.lazy')
