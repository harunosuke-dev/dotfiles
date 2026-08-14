# スクリプトリファレンス / Scripts Reference

dotfilesで利用可能な各スクリプトの詳細な説明とオプションについて記載します。

## 概要 / Overview

`bin/`内の再利用可能なスクリプトは`bin/setup-links.sh`実行後に`~/.local/bin/`からグローバルにアクセス可能になります。

Reusable scripts in `bin/` become globally accessible from `~/.local/bin/` after running `bin/setup-links.sh`.

---

## インストールスクリプト / Installation Scripts

### `install.sh`

**概要**: メインのインストールスクリプト  
**用途**: dotfilesの初期インストールとアップデート  

```bash
git clone https://github.com/harunosuke-dev/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh
```

または、bootstrapスクリプトにcloneと再実行を任せます。

```bash
curl -fsSL https://raw.githubusercontent.com/harunosuke-dev/dotfiles/main/install.sh | sh
```

#### 実行内容
1. **事前チェック**
   - macOSの確認
   - インターネット接続テスト  
   - gitの存在確認（Command Line Tools自動インストール）
2. **リポジトリクローン**: `~/.dotfiles`
3. **clone済み`install.sh`へ再実行**: `curl | sh`の場合のみ
4. **セットアップモード選択**
   - **[1] フルセットアップ**: 全スクリプト実行（新しいマシン推奨）
   - **[2] アップデートのみ**: Homebrew、開発ツール、リンク更新のみ
   - **[3] セットアップスキップ**: リポジトリ更新のみ

#### 自動化対応
```bash
# 環境変数による非対話実行
BOOTSTRAP_MODE=2 ./install.sh
```

#### エラーハンドリング
- エラー発生時に行番号を表示
- 詳細なエラーメッセージ
- 失敗時の復旧手順提示

---

### `setup`

**概要**: 全セットアップスクリプトの統合実行  
**場所**: `scripts/setup.sh`

```bash
setup.sh
```

#### 実行順序
1. `setup-nix.sh install` - Nix本体
2. `setup-homebrew.sh` - Homebrewとパッケージ（`stow`を含む）
3. `bin/setup-links.sh` - 設定ファイルリンク
4. `setup-local-config.sh` - ローカル設定
5. `setup-nix.sh apply` - nix-darwinシステム設定
6. `setup-apt.sh` - APT（macOSではスキップ）
7. `setup-mise.sh` - 開発環境
8. `setup-zinit.sh` - シェル環境
9. `setup-bat.sh` - テーマキャッシュ
10. `setup-nvim.sh` - エディタ設定
11. `setup-login.sh` - ログイン

各ステップは独立して実行され、失敗しても後続ステップを試します。最後のサマリーに成功・スキップ・失敗が表示され、失敗が1件以上あれば全体の終了コードは非0になります。

### `setup-nix.sh`

```bash
setup-nix.sh install
setup-nix.sh apply
```

- Nix未導入時は公式multi-userインストーラーを実行
- Macの`LocalHostName`と同名の`darwinConfigurations`を自動選択
- `NIX_DARWIN_CONFIG`で構成名を上書き可能
- `system.primaryUser`と現在ユーザーが異なる場合はNix適用のみスキップ
- 初回nix-darwin適用前に、管理対象となる既存`/etc`シェル設定を退避

---

## ローカル設定 / Local Configuration

### `setup-local-config.sh`

**概要**: プライベート情報の設定とローカル環境設定
**対象**: メールアドレス、Git設定、Google Drive設定など

```bash
setup-local-config.sh
```

#### 実行内容
1. **既存チェック**: `~/.config/zsh/.zshrc.local`の存在確認
2. **インタラクティブ設定**: メールアドレス等の入力
3. **Google Drive検出**: 自動的にGoogle Driveの設定を検出
4. **テンプレート処理**: `.zshrc.local.template`から設定ファイルを生成

#### 設定される項目
- **EMAIL**: プライマリメールアドレス
- **GIT_AUTHOR_EMAIL**: Git作成者メール（プライマリを参照）
- **GIT_COMMITTER_EMAIL**: Gitコミッターメール（プライマリを参照）
- **GOOGLE_DRIVE_EMAIL**: Google Drive用メール（異なる場合のみ）

#### 特徴
- **スキップ機能**: 既存設定がある場合は自動スキップ
- **readline対応**: バックスペース、矢印キーが正常動作
- **自動検出**: Google Driveインストール状況を検出

---

## Linux環境サポート / Linux Support

### `setup-apt.sh`

**概要**: APTパッケージマネージャーを使用したLinux環境でのパッケージ管理
**対象**: Debian/Ubuntu系Linux環境

```bash
setup-apt.sh
```

#### 実行内容
1. **APT存在確認**: apt-getコマンドの確認
2. **パッケージインストール**: `apt/install.sh`の実行
3. **環境変数チェック**: `SKIP_APT`による実行制御

#### 制御オプション
```bash
export SKIP_APT=true  # APTセットアップをスキップ
```

---

## パッケージ管理 / Package Management

### `setup-homebrew.sh`

**概要**: Homebrewのインストールと設定  
**対応アーキテクチャ**: Intel (x86_64) & Apple Silicon (arm64)

```bash
setup-homebrew.sh [OPTIONS]
```

#### オプション
| オプション | 説明 |
|------------|------|
| `-s, --skip-apps` | アプリのインストールをスキップ |
| `-v, --verbose` | 詳細出力 |
| `-u, --update` | Homebrew自体を更新し、任意アプリをスキップ |

#### 実行内容
1. **アーキテクチャ判定**: Intel/Apple Silicon自動判定
2. **Homebrew インストール**
   - Intel: `/usr/local/bin/brew`
   - Apple Silicon: `/opt/homebrew/bin/brew`
3. **パッケージインストール**: Brewfileからの一括インストール
4. **事前チェック**: Command Line Tools確認

#### Brewfile場所
- `${REPO_DIR}/homebrew/Brewfile`
- `${GHQ_ROOT_PATH}/github.com/${GITHUB_USER_NAME}/dotfiles/homebrew/Brewfile`

#### 使用例
```bash
# 通常インストール
setup-homebrew.sh

# アプリをスキップしてHomebrewのみ
setup-homebrew.sh --skip-apps

# 詳細出力でデバッグ
setup-homebrew.sh --verbose

# Homebrewを更新してからパッケージインストール
setup-homebrew.sh --update
```

---

### `setup-mise.sh`

**概要**: 開発ランタイム環境の管理  
**前身**: asdfからの移行

```bash
setup-mise.sh [OPTIONS]
```

#### オプション
| オプション | 説明 |
|------------|------|
| `-s, --skip-update` | mise自体の更新をスキップ |

#### 環境変数（XDG準拠）
```bash
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"
```

#### 実行内容
1. **miseインストール**: Homebrew経由
2. **ツールインストール**: `~/.tool-versions`から読み込み
3. **グローバル設定**: バージョン設定の適用
4. **プラグイン更新**: mise pluginsの最新化

#### サポートツール例
- **Node.js**: `node 18.17.0`
- **Python**: `python 3.11.4`
- **Ruby**: `ruby 3.2.2`
- **Go**: `go 1.21.0`
- **その他**: Java, Rust, PHP, Deno等

#### `.tool-versions` 例
```
node 18.17.0
python 3.11.4
ruby 3.2.2
go 1.21.0
```

---

## 設定ファイル管理 / Configuration Management

### `bin/setup-links.sh`

**概要**: GNU stowを使用した設定ファイルのシンボリックリンク管理
**最重要**: 他のスクリプトをグローバルアクセス可能にする

```bash
bin/setup-links.sh [OPTIONS]
```

#### オプション
| オプション | 説明 |
|------------|------|
| `-u, --unlink PACKAGES` | 指定パッケージのリンクを解除 |
| `-uall, --unlink-all` | 全リンクを解除 |

#### 実行内容

##### 1. リンク解除モード
```bash
# 特定パッケージ
bin/setup-links.sh --unlink vim nvim

# 全パッケージ + スクリプト
bin/setup-links.sh --unlink-all
```

##### 2. 通常リンク作成
```bash
bin/setup-links.sh
```
1. **自動クリーンアップ**: dotfilesパッケージを指す壊れたリンクを自動削除
2. **必要ディレクトリ作成**
   ```
   $XDG_CONFIG_HOME
   $XDG_STATE_HOME  
   $XDG_CACHE_HOME
   $HOME/.ssh (権限700)
   ```

3. **パッケージリンク**: `packages/`内の全ディレクトリをstowでリンク
4. **スクリプトリンク**: `bin/`内のスクリプトを`$HOME/.local/bin`にリンク

#### ⭐️ グローバルスクリプトアクセス機能
```bash
# この処理により全スクリプトがグローバルアクセス可能に
ln -sf "$DOTFILES_HOME/bin/"* "$HOME/.local/bin"
```

#### パッケージ構造例
```
packages/
├── zsh/
│   └── .zshrc
├── vim/
│   └── .vimrc
└── git/
    └── .gitconfig
```

#### 安全機能
- **自動バックアップ**: 既存ファイルを`~/.local/state/dotfiles/backup/`に保存
- **インテリジェントリンク**: 正しいリンクは再作成をスキップ
- **安全な上書き**: バックアップ後にリンク作成

---

## シェル環境 / Shell Environment

### `setup-zinit.sh`

**概要**: Zshプラグインマネージャーzinitのインストール

```bash
setup-zinit.sh
```

#### インストール場所
- **クローン先**: `$GHQ_ROOT_PATH/github.com/zdharma-continuum/zinit`
- **シンボリックリンク**: `$XDG_DATA_HOME/zinit/bin`

#### 実行内容
1. **リポジトリ確認**: 既存インストールの更新またはクローン
2. **シンボリックリンク作成**: XDG準拠の場所にリンク
3. **セットアップ完了通知**: 新しいシェルセッションでの利用を案内

#### 利用方法
```bash
# 新しいシェルセッション開始
exec zsh

# または手動で設定読み込み
source ~/.zshenv && source "$XDG_CONFIG_HOME/zsh/.zshrc"
```

---

### `setup-nvim.sh` & `setup-login.sh`

**概要**: エディタとログインシェルの設定

```bash
setup-nvim.sh   # Neovim設定
setup-login.sh  # ログインシェル設定  
```

*詳細は個別の設定ファイル内容に依存*

---

## システム更新 / System Update

### `bin/update.sh`

**概要**: 統合パッケージマネージャー更新スクリプト
**対象**: Homebrew、zinit、mise

```bash
update [OPTIONS] [MANAGERS...]
```

#### オプション
| オプション | 説明 |
|------------|------|
| `--dry-run` | 実際の更新は行わずプレビューのみ |
| `--force` | 確認プロンプトをスキップして強制実行 |
| `--manager-only` | パッケージマネージャー本体のみを更新 |
| `--packages-only` | インストール済みパッケージ/プラグイン/ツールのみを更新 |
| `--all` | 全パッケージマネージャーを対象とする |
| `-h, --help` | ヘルプメッセージを表示 |

#### パッケージマネージャー
| 引数 | 説明 |
|------|------|
| `homebrew`, `brew` | Homebrewとパッケージを更新 |
| `zinit` | zinitとプラグインを更新 |
| `mise` | miseとツールを更新 |

#### 使用例
```bash
# 2段階選択：パッケージマネージャー選択 → 更新範囲選択
update

# 全パッケージマネージャーを対象に更新範囲選択
update --all

# 特定のマネージャーのみ更新
update homebrew
update zinit mise

# パッケージマネージャー本体のみ更新
update --manager-only

# パッケージのみ更新
update --packages-only

# プレビューモード
update --dry-run
update --dry-run homebrew

# 強制実行
update --force zinit
```

#### 特徴
- **2段階選択**: パッケージマネージャー選択 → 更新範囲選択の直感的なUI
- **包括的更新**: パッケージマネージャー本体 + 管理パッケージの両方
- **柔軟な更新範囲**: 本体のみ、パッケージのみ、または両方を選択
- **事前チェック**: ネットワーク接続・ツール存在確認
- **詳細ログ**: `~/.local/state/system-update.log`に記録
- **エラー処理**: 失敗したマネージャーをレポート
- **zsh補完**: タブキーで引数・オプション補完
- **manページ**: `man update`で詳細マニュアル

#### 更新内容詳細
**Homebrew**:
- `brew update` (パッケージリスト更新) - **本体**
- `brew upgrade` (インストール済みパッケージ更新) - **パッケージ**
- `brew cleanup` (古いバージョン削除) - **パッケージ**

**zinit**:
- `zinit self-update` (zinit本体更新) - **本体**
- `zinit update --all` (全プラグイン更新) - **プラグイン**

**mise**:
- `mise self-update` (mise本体更新) - **本体** ※パッケージマネージャー経由インストールの場合はスキップ
- `mise upgrade` (管理ツール更新) - **ツール**

#### インタラクティブ選択

**1. パッケージマネージャー選択** (`update`コマンド単体時)：
```
Which package managers would you like to update?
[1] All (homebrew, zinit, mise)
[2] Homebrew only
[3] zinit only
[4] mise only
[5] Custom selection

Choose [1/2/3/4/5]:
```

**2. 更新範囲選択**：
```
What would you like to update?
[1] Both package managers and packages/plugins/tools (default)
[2] Package managers only (brew update, zinit self-update, mise self-update)
[3] Packages/plugins/tools only (brew upgrade, zinit update --all, mise upgrade)

Choose [1/2/3]:
```

---

## ユーティリティ関数 / Utility Functions

### バックアップ管理

#### `list_backups`
```bash
list_backups [BACKUP_DIR]
```
**機能**: バックアップファイル一覧表示  
**デフォルト場所**: `$XDG_STATE_HOME/dotfiles/backup`

#### `restore_backup`
```bash
restore_backup BACKUP_FILE [TARGET] [BACKUP_DIR]
```
**機能**: バックアップファイルから復元  
**例**:
```bash
restore_backup ".vimrc.20250109_143022"
restore_backup ".vimrc.20250109_143022" "$HOME/.vimrc"
```

#### `clean_old_backups`
```bash
clean_old_backups [BACKUP_DIR] [KEEP_COUNT]
```
**機能**: 古いバックアップを削除（デフォルト: 最新5個を保持）  
**例**:
```bash
clean_old_backups                    # 最新5個保持
clean_old_backups "" 3              # 最新3個保持
```

### 依存関係チェック

#### `check_dependencies`
```bash
check_dependencies COMMAND1 COMMAND2 ...
```
**機能**: 複数コマンドの存在確認

#### `check_xcode_tools`
```bash
check_xcode_tools
```
**機能**: Command Line Toolsの確認とインストール

#### `check_internet`
```bash
check_internet
```
**機能**: インターネット接続確認

### その他のユーティリティ

#### `safe_symlink`
```bash
safe_symlink SOURCE TARGET
```
**機能**: 安全なシンボリックリンク作成（バックアップ付き）

#### `backup_file`
```bash
backup_file FILE [BACKUP_DIR]  
```
**機能**: ファイルの手動バックアップ

#### `command_exists`
```bash
command_exists COMMAND
```
**機能**: コマンドの存在確認

#### `is_macos`
```bash
is_macos
```
**機能**: macOS判定

---

## 環境変数 / Environment Variables

### グローバル制御
```bash
export SKIP_HOMEBREW=true    # Homebrewセットアップをスキップ
export SKIP_APT=true         # APTパッケージをスキップ（macOSでは自動設定）
export INSTALL_DIR="/path"   # インストール先ディレクトリ変更
export NIX_DARWIN_CONFIG="papinocom" # LocalHostNameと異なる構成名を選択
```

### XDG Base Directory
```bash
export XDG_CONFIG_HOME="$HOME/.config"        # 設定ファイル
export XDG_DATA_HOME="$HOME/.local/share"     # データファイル  
export XDG_STATE_HOME="$HOME/.local/state"    # 状態ファイル
export XDG_CACHE_HOME="$HOME/.cache"          # キャッシュファイル
```

### mise環境変数
```bash
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"  
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"
```

---

## トラブルシューティング / Troubleshooting

### よくあるエラー / Common Errors

#### 1. Command Line Tools関連
```bash
# エラー: xcode-select: error: tool 'xcodebuild' requires Xcode
xcode-select --install

# リセットが必要な場合
sudo xcode-select --reset
sudo xcode-select --install
```

#### 2. Homebrew権限エラー
```bash
# 権限の修正
sudo chown -R $(whoami) /usr/local/var/homebrew
sudo chown -R $(whoami) /opt/homebrew  # Apple Silicon

# 再インストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
setup-homebrew.sh
```

#### 3. 壊れたシンボリックリンク
```bash
# setup-links.sh実行時に自動クリーンアップ
setup-links.sh

# 手動確認
find $HOME -type l ! -exec test -e {} \; -print 2>/dev/null
```

#### 4. mise/開発ツールエラー
```bash
# mise再インストール
brew uninstall mise
brew install mise

# 設定リセット
rm -rf "$XDG_DATA_HOME/mise" "$XDG_CONFIG_HOME/mise"
setup-mise.sh
```

### デバッグ方法 / Debugging

#### 詳細ログ出力
```bash
# bash -x でスクリプト実行をトレース
bash -x setup-homebrew.sh --verbose

# エラー箇所の特定
setup-links.sh 2>&1 | grep -A5 -B5 "ERROR"
```

#### 段階的実行
```bash
# 個別スクリプト実行でエラー箇所を特定
scripts/setup-nix.sh apply  # nix-darwinシステム設定
setup-homebrew.sh        # パッケージ管理のみ
setup-links.sh           # リンク作成のみ
```

#### 状態確認
```bash
# インストール状況確認
which brew mise stow git
brew --version
mise --version

# リンク状況確認  
ls -la ~/.zshrc ~/.vimrc ~/.gitconfig

# バックアップ確認
list_backups
```

---

## 開発・カスタマイズ / Development & Customization

### 新しいスクリプトの追加

1. **スクリプト作成**: `scripts/my-script.sh`
2. **実行権限**: `chmod +x scripts/my-script.sh`  
3. **リンク更新**: `setup-links.sh`
4. **グローバル実行**: `my-script`

### 新しいパッケージの追加

1. **ディレクトリ作成**: `packages/my-config/`
2. **設定ファイル配置**: 適切なディレクトリ構造で配置
3. **リンク作成**: `setup-links.sh`

#### パッケージ構造例
```
packages/my-config/
├── .config/
│   └── my-app/
│       └── config.yaml
└── .my-app-rc
```

### Brewfileカスタマイズ

#### dotfiles管理のBrewfile編集

`homebrew/Brewfile`を編集:
```ruby
# CLI tools
brew "fd"
brew "ripgrep"
brew "bat"

# Applications
cask "visual-studio-code"
cask "docker"

# Fonts
cask "font-fira-code-nerd-font"
```

#### ローカル環境専用のBrewfile生成

現在のシステムにインストール済みのパッケージから自動生成：

```bash
# 基本コマンド（このdotfiles環境では ~/.config/homebrew/Brewfile に作成）
brew bundle dump

# 既存ファイルを強制上書き
brew bundle dump --force

# 生成されたファイルの確認
cat ~/.config/homebrew/Brewfile
```

**⚠️ 重要な注意事項**:
- `--force` オプションは既存のBrewfileを**完全に上書き**します
- 手動で編集した内容がある場合は事前にバックアップを取ってください
- 生成されたBrewfileは全てのインストール済みパッケージを含むため、不要なものは手動で削除してください

**💡 このdotfiles環境では**: 環境変数 `HOMEBREW_BUNDLE_FILE` により、`brew bundle dump` は自動的にXDG準拠の場所（`~/.config/homebrew/Brewfile`）に作成されます。環境変数が設定されていない場合は、カレントディレクトリに `Brewfile` が作成されます。

#### ローカルBrewfileの活用例

```bash
# ローカルBrewfileからのパッケージインストール
brew bundle install

# 特定のパッケージのみインストール
brew bundle install --grep "vscode"

# インストール状況の確認
brew bundle check
```

---

## リファレンス / Reference

### 関連リンク
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/)
- [mise Documentation](https://mise.jdx.dev/)
- [Homebrew Documentation](https://docs.brew.sh/)
- [zinit Wiki](https://github.com/zdharma-continuum/zinit/wiki)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)

### ファイル配置
```
~/.dotfiles/
├── install.sh               # メインインストーラー
├── bin/                     # 再利用可能スクリプト（グローバルアクセス可能）
│   ├── setup-links.sh   # シンボリックリンク管理
│   └── update.sh        # 統合パッケージ更新
├── scripts/                 # セットアップスクリプト
│   ├── setup.sh          # 統合セットアップ
│   ├── setup-local-config.sh # ローカル設定
│   ├── setup-homebrew.sh # Homebrew管理
│   ├── setup-nix.sh      # Nix導入・nix-darwin適用
│   ├── setup-apt.sh      # APTパッケージ管理（Linux用）
│   ├── setup-mise.sh     # 開発環境管理
│   ├── setup-zinit.sh    # シェル環境
│   ├── setup-nvim.sh     # Neovim設定
│   ├── setup-login.sh    # ログインシェル設定
│   ├── common.sh         # 共通設定
│   └── utils.sh          # ユーティリティ関数
├── packages/               # stow管理の設定ファイル
├── homebrew/              # Homebrewパッケージ定義
└── docs/                  # ドキュメント
```

---

最終更新: 2025年9月14日
