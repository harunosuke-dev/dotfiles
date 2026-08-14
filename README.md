# dotfiles

Personal dotfiles setup (Primary: macOS, Limited: Linux)

Managed by:

- [Nix](https://nixos.org/) / [nix-darwin](https://github.com/nix-darwin/nix-darwin) - macOS system configuration
- [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle) - Package management and dependency installation
- [GNU stow](https://www.gnu.org/software/stow/) - Symlink management for dotfiles
- [zinit](https://github.com/zdharma-continuum/zinit) - Fast zsh plugin manager / Lazy load
- [mise](https://github.com/jdx/mise) - Runtime version management (Node.js, Python, etc.)

## Installation

```bash
git clone https://github.com/harunosuke-dev/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh
```

短縮形も使える。`~/.dotfiles`へcloneした後、clone済みの`install.sh`へ自動的に切り替わる。

```bash
curl -fsSL https://raw.githubusercontent.com/harunosuke-dev/dotfiles/main/install.sh | sh
```

### Setup Modes

実行すると3つの選択肢が表示される。

| モード | 内容                                                  |
| ------ | ----------------------------------------------------- |
| 1      | フルセットアップ - 新しいマシンの初回構築はこれ       |
| 2      | 更新のみ - Homebrew・mise・シンボリックリンクの再実行 |
| 3      | リポジトリの更新のみ（セットアップはスキップ）        |

`BOOTSTRAP_MODE`を付けると、対話プロンプトなしで実行できる。

```bash
BOOTSTRAP_MODE=1 ./install.sh
```

各ステップは独立して実行され、失敗しても後続を試す。最後に成功・スキップ・失敗のサマリーが出る。

## Structure

```
install.sh   セットアップの入口。scripts/setup.sh を呼ぶ
bin/         ユーザーが直接叩くスクリプト（setup-links / update / doctor）
scripts/     セットアップ用の内部スクリプト（common.sh に共通変数）
packages/    stowパッケージ群（1ツール1ディレクトリ）
homebrew/    Brewfile
apt/         Linux向けパッケージインストール
nix/         nix-darwinによるmacOSシステム設定
docs/        セットアップ手順・スクリプト解説
man/         自作スクリプトのmanページ
```

## Documentation

- [docs/SETUP.md](docs/SETUP.md) — セットアップ手順、前提条件、バックアップ、カスタマイズ、トラブルシューティング
- [docs/SCRIPTS.md](docs/SCRIPTS.md) — 各スクリプトのオプションと実行内容、ユーティリティ関数、環境変数

設定と実環境のズレ（壊れたリンク・実体のない設定・Brewfile差分）は`doctor`で検査できる。

```bash
doctor
```
