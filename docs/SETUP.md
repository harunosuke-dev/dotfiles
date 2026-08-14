# セットアップガイド

個人用dotfilesのセットアップと使用方法について説明します。

## インストール

```bash
git clone https://github.com/harunosuke-dev/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh
```

`curl | sh`を使った場合も、`~/.dotfiles`へcloneした後にリポジトリ内の`install.sh`が再実行されます。

```bash
curl -fsSL https://raw.githubusercontent.com/harunosuke-dev/dotfiles/main/install.sh | sh
```

### インタラクティブモード

実行時に以下の選択肢が表示されます：

1. **フルセットアップ** - 新しいマシン向け（推奨）
2. **アップデートのみ** - 既存環境での更新（Homebrew、開発ツール、リンク再作成）
3. **セットアップスキップ** - リポジトリ更新のみ

### 自動化モード

環境変数で非対話実行も可能：

```bash
# フルセットアップ
BOOTSTRAP_MODE=1 ./install.sh

# アップデートのみ  
BOOTSTRAP_MODE=2 ./install.sh

# セットアップスキップ
BOOTSTRAP_MODE=3 ./install.sh
```

## 前提条件

- **プライマリOS**: このセットアップはmacOSに最適化されています
- **Linux対応**: 限定的にLinux環境でも利用可能（Homebrew非対応機能は制限あり）
- **インターネット接続**: パッケージのダウンロードに必要
- **Command Line Tools**: 不足している場合は自動インストール（macOSのみ）

## セットアップ内容

### インストールされるもの

- **Nix / nix-darwin**: macOSのシステム設定を宣言的に管理
- **Homebrew**: macOSのパッケージマネージャー
- **mise**: ランタイムバージョン管理ツール
- **zinit**: Zshプラグインマネージャー
- **GNU stow**: dotfilesのシンボリックリンク管理
- **各種CLIツール**: `homebrew/Brewfile`で定義

### 実行される処理

1. **事前チェック**: macOS確認、ネット接続、gitの存在確認（Command Line Tools自動インストール）

   **⭐️ 新品のMacでの初回実行**：
   - Command Line Toolsインストールダイアログが自動表示
   - 「Install」クリック後、スクリプトが自動で完了を待機
   - インストール完了後、自動的に処理続行
2. **リポジトリクローン**: `~/.dotfiles`に配置
3. **各種セットアップスクリプト実行**:
   - Nix本体をインストール
   - Homebrewとパッケージをインストール（`stow`を含む）
   - dotfilesのシンボリックリンクを作成
   - ローカル設定（環境変数、プライベート情報）を作成
   - nix-darwinでmacOSシステム設定を反映
   - mise、zinit、bat、Neovim、GitHub CLIをセットアップ

各ステップの失敗は記録して残りの処理を続行し、最後に成功・スキップ・失敗をまとめて表示します。
nix-darwin構成が現在のMacまたはユーザーに一致しない場合も、Nixの適用だけをスキップします。

## グローバルスクリプトアクセス

`setup-links.sh`により、`bin/`ディレクトリ内の再利用可能なスクリプト（`update.sh`, `setup-links.sh`）が`~/.local/bin/`にシンボリックリンクされ、どこからでも実行可能になります。

### 利用可能なコマンド

```bash
# ローカル設定
setup-local-config.sh             # ローカル設定ファイルのセットアップ

# Homebrew関連
setup-homebrew.sh --update        # Homebrewとパッケージを更新
setup-homebrew.sh --skip-apps     # Homebrewのみインストール、アプリはスキップ

# 開発環境
setup-mise.sh                      # 開発ツールのインストール/更新
setup-mise.sh --skip-update       # mise自体の更新をスキップ

# 設定ファイル管理
setup-links.sh                     # 全dotfilesを再リンク（壊れたリンクを自動クリーンアップ）
setup-links.sh --unlink package   # 特定パッケージのリンクを解除
setup-links.sh --unlink-all       # 全リンクを解除

# システム設定
setup-nix.sh apply

# シェル環境
setup-zinit.sh                     # zinitを再インストール/更新
```

## バックアップシステム

### 自動バックアップ

既存ファイルを上書きする前に自動でバックアップを作成：

- **保存場所**: `~/.local/state/dotfiles/backup/`（XDG準拠）
- **命名規則**: `ファイル名.YYYYMMDD_HHMMSS`
- **対象**: 上書きされる既存の設定ファイル

### バックアップ管理

```bash
# バックアップ一覧表示
list_backups

# バックアップから復元
restore_backup ".vimrc.20250109_143022"

# 古いバックアップ削除（ファイルごとに最新5個を保持）
clean_old_backups
```

## カスタマイズ

### ローカル設定

**プライベート情報の管理**

このdotfilesはGitHubで公開されているため、メールアドレスなどのプライベート情報は別途管理されます：

- **設定ファイル**: `~/.config/zsh/.zshrc.local`（gitignoreに含まれる）
- **テンプレート**: `.config/zsh/.zshrc.local.template`
- **自動セットアップ**: `setup-local-config.sh`スクリプトが初回実行時に自動で設定

#### Google Drive設定

スクリーンショットをGoogle Driveに保存する場合：

```bash
# 自動検出（Google Driveがインストール済みの場合）
setup-local-config.sh

# 手動設定（~/.config/zsh/.zshrc.localに追加）
export EMAIL="your-primary@email.com"           # プライマリメールアドレス
export GIT_AUTHOR_EMAIL="$EMAIL"                # Git用（プライマリを参照）
export GIT_COMMITTER_EMAIL="$EMAIL"             # Git用（プライマリを参照）
export GOOGLE_DRIVE_EMAIL="your-google@email.com" # Google Drive用（異なる場合のみ）
```

スクリーンショット保存先はnix-darwinのLaunchAgentがGoogle Driveを自動検出して設定します。

### 環境変数

```bash
export SKIP_HOMEBREW=true           # Homebrewインストールをスキップ
export INSTALL_DIR="/custom/path"   # インストール先を変更
```

### パッケージ追加

- **Homebrewパッケージ**: `homebrew/Brewfile`を編集
- **開発ツール**: `.mise.toml`を編集（公式推奨）または`~/.tool-versions`（asdf互換）
- **カスタムスクリプト**: `scripts/`ディレクトリに追加

### Homebrewファイルの使い分け

- **`homebrew/Brewfile`**: dotfilesリポジトリで管理される基本パッケージ定義
- **`~/.config/homebrew/Brewfile`**: ローカル環境での追加パッケージやカスタマイズ
  - 環境変数`HOMEBREW_BUNDLE_FILE`で参照先を指定
  - ローカルでのみ必要なパッケージを追加可能
  - dotfilesで管理したい場合は手動でコピーして追加

#### ローカルBrewfile作成コマンド

現在インストール済みのパッケージからBrewfileを生成：

```bash
# 基本コマンド（このdotfiles環境では ~/.config/homebrew/Brewfile に作成）
brew bundle dump

# 強制上書き（既存ファイルがある場合は注意！）
brew bundle dump --force
```

**⚠️ 注意**: `--force` オプションは既存のBrewfileを上書きします。重要な設定がある場合は事前にバックアップを取ってください。

**💡 このdotfiles環境では**: 環境変数 `HOMEBREW_BUNDLE_FILE` により、自動的にXDG準拠の場所（`~/.config/homebrew/Brewfile`）が使用されます。環境変数が設定されていない場合は、カレントディレクトリに `Brewfile` が作成されます。

## エラー処理

### 安全機能

- エラー発生時の行番号表示
- 依存関係の事前チェック
- 冪等性（複数回実行しても安全）
- 既存設定のバックアップ
- インターネット接続確認

### トラブルシューティング

#### よくある問題

1. **Command Line Toolsが未インストール**

   ```bash
   xcode-select --install
   ```

2. **権限エラー**

   ```bash
   sudo xcode-select --reset
   ```

3. **アップデート後のリンク切れ**

   ```bash
   setup-links.sh  # 実行時に壊れたリンクを自動クリーンアップ
   ```

#### ログ出力

- 📌 一般的な情報
- ℹ️  詳細情報
- ✅ 成功
- ⚠️  警告（継続可能）
- ❌ エラー（致命的）
- 🔄 処理ステップ

## 部分的なインストール

```bash
# Homebrewのみ
export SKIP_MISE=true
export SKIP_ZINIT=true
./scripts/setup.sh

# 開発ツールのみ更新
setup-mise.sh
```

## 複数マシンでの同期

```bash
# 新しいマシン
git clone https://github.com/harunosuke-dev/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh

# 既存インストールの更新
cd "$HOME/.dotfiles"
git pull
./scripts/setup.sh
```

---

# Setup Guide (English)

Personal dotfiles setup and usage instructions.

## Installation

```bash
git clone https://github.com/harunosuke-dev/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh
```

## Prerequisites

- **macOS**: This setup is macOS-specific
- **Internet Connection**: Required for package downloads
- **Command Line Tools**: Auto-installed if missing

## What Gets Installed

- **Nix / nix-darwin**: Declarative macOS system configuration
- **Homebrew**: macOS package manager
- **mise**: Runtime version manager
- **zinit**: Zsh plugin manager
- **GNU stow**: Dotfiles symlink manager
- **CLI tools**: Defined in `homebrew/.config/homebrew/Brewfile`

## Setup Process

1. **Pre-checks**: macOS verification, internet connection, git availability
2. **Repository cloning**: To `~/.dotfiles`
3. **Setup execution**:
   - Install Nix
   - Install Homebrew packages, including GNU Stow
   - Link dotfiles and create local configuration
   - Apply the matching nix-darwin configuration
   - Set up mise, zinit, bat, Neovim, and GitHub CLI

Steps are attempted independently. Failures and skipped steps are collected and shown in the final summary.

## Local Configuration

**Private Information Management**

Since these dotfiles are publicly available on GitHub, private information like email addresses is managed separately:

- **Configuration file**: `~/.config/zsh/.zshrc.local` (included in gitignore)
- **Template**: `.config/zsh/.zshrc.local.template`
- **Auto-setup**: `setup-local-config.sh` script automatically configures on first run

### Google Drive Setup

For saving screenshots to Google Drive:

```bash
# Auto-detection (if Google Drive is installed)
setup-local-config.sh

# Manual setup (add to ~/.config/zsh/.zshrc.local)
export EMAIL="your-primary@email.com"           # Primary email address
export GIT_AUTHOR_EMAIL="$EMAIL"                # For Git (references primary)
export GIT_COMMITTER_EMAIL="$EMAIL"             # For Git (references primary)
export GOOGLE_DRIVE_EMAIL="your-google@email.com" # For Google Drive (only if different)
```

The nix-darwin LaunchAgent detects Google Drive and configures the native screenshot location.

## グローバルスクリプトアクセス

`bin/`内の再利用可能なスクリプトは`setup-links.sh`により`~/.local/bin/`にシンボリックリンクされ、グローバルアクセス可能になります。

## 利用可能なコマンド

### セットアップ系コマンド
```bash
setup-local-config.sh         # ローカル設定のセットアップ
setup-homebrew.sh --update    # Homebrewとパッケージの更新
setup-mise.sh                 # 開発ツールのインストール/更新
setup-links.sh                # dotfilesの再リンク（壊れたリンクの自動クリーンアップ）
setup-nix.sh apply            # nix-darwin設定の再適用
```

### システム更新コマンド
```bash
# 全パッケージマネージャーの更新
update                        # 全パッケージマネージャー（Homebrew、zinit、mise）
update --dry-run              # 変更を加えずに更新内容をプレビュー
update --force                # 確認プロンプトをスキップして即座に更新

# 特定のパッケージマネージャーのみ更新
update homebrew               # Homebrewのみ更新
update brew                   # Homebrewのみ更新（エイリアス）
update zinit                  # zinitのみ更新
update mise                   # miseのみ更新
update homebrew mise          # 複数指定も可能

# オプションとの組み合わせ
update --dry-run homebrew     # Homebrewの更新をプレビュー
update --force zinit          # zinitを強制更新

# ヘルプとマニュアル
update --help                 # 使用方法の表示
man update                    # 詳細なマニュアル表示
```

**システム更新機能の特徴：**
- ✅ **安全な実行**: 包括的なエラーハンドリングとロールバック機能
- ✅ **進行状況ログ**: 詳細なログを`~/.local/state/system-update.log`に保存
- ✅ **事前チェック**: ネットワーク接続とツール利用可能性の検証
- ✅ **インタラクティブ確認**: 変更前のユーザー確認（--forceでない場合）
- ✅ **クロスシェル対応**: sh/bash/zsh環境から動作
- ✅ **選択的更新**: 特定のパッケージマネージャーのみ更新可能
- ✅ **zsh補完**: タブキーでオプション・引数のサジェスト
- ✅ **manページ**: `man update`で詳細なマニュアル表示

## Global Script Access

Reusable scripts in `bin/` are symlinked to `~/.local/bin/` via `setup-links.sh`, making them globally accessible.

## Available Commands

### Setup Commands

```bash
scripts/setup-local-config.sh # Setup local configuration
scripts/setup-homebrew.sh --update # Update Homebrew and packages
scripts/setup-mise.sh         # Install/update development tools
bin/setup-links.sh            # Relink all dotfiles (automatically cleans broken links)
scripts/setup-nix.sh apply    # Reapply nix-darwin settings
```

### System Update Commands

```bash
# Update all package managers
update                        # All package managers (Homebrew, zinit, mise)
update --dry-run              # Preview what would be updated without making changes
update --force                # Skip confirmation prompts and update immediately

# Update specific package managers only
update homebrew               # Update only Homebrew
update brew                   # Update only Homebrew (alias)
update zinit                  # Update only zinit
update mise                   # Update only mise
update homebrew mise          # Multiple managers supported

# Combine with options
update --dry-run homebrew     # Preview Homebrew updates
update --force zinit          # Force update zinit

# Help and manual
update --help                 # Show usage information
man update                    # Show detailed manual page
```

**System Update Features:**

- ✅ **Safe execution**: Comprehensive error handling and rollback capability
- ✅ **Progress logging**: Detailed logs saved to `~/.local/state/system-update.log`
- ✅ **Prerequisites check**: Network connectivity and tool availability verification
- ✅ **Interactive confirmation**: User confirmation before making changes (unless --force)
- ✅ **Cross-shell compatibility**: Works from sh/bash/zsh environments
- ✅ **Selective updates**: Update specific package managers only
- ✅ **zsh completion**: Tab key suggestions for options and arguments
- ✅ **Manual page**: `man update` for detailed documentation

## Backup System

- **Location**: `~/.local/state/dotfiles/backup/`
- **Format**: `filename.YYYYMMDD_HHMMSS`
- **Management**: `list_backups`, `restore_backup`, `clean_old_backups`
