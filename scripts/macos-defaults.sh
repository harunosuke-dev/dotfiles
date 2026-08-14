#!/bin/sh

echo "📌 Configuring macOS default settings"

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
# sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
# while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=%00

###########################################################
# System Interface & Appearance
###########################################################

# Interface Style
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark # ダークモードに設定 #default: Light

# Performance & Animation
defaults write -g NSWindowResizeTime -float 0.001                     # ダイアログ・ウィンドウリサイズ速度を高速化 #default: 0.2
defaults write com.apple.Accessibility ReduceMotionEnabled -bool true # 視覚効果・モーション・アニメーションを減らす #default: false
defaults write -g NSScrollViewRubberbanding -bool false               # スクロール時のバウンドアニメーションを停止 #default: true
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false      # ファイル・ウィンドウアニメーションを停止 #default: true

###########################################################
# Security & Privacy
###########################################################

# Screen Saver & Lock
defaults write com.apple.screensaver askForPassword -bool true  # スリープ復帰時パスワード要求 #default: true
defaults write com.apple.screensaver askForPasswordDelay -int 0 # パスワード要求遅延時間（秒） #default: 0

# Download Security
defaults write com.apple.LaunchServices LSQuarantine -bool false # ダウンロードファイル警告ダイアログ表示 #default: true

# System Integrity
defaults write com.apple.CrashReporter DialogType none # クラッシュリポーターダイアログ表示 #default: "crashreport"

###########################################################
# File System & Storage
###########################################################

# File Extensions & Hidden Files
defaults write NSGlobalDomain AppleShowAllExtensions -bool true # 全てのファイル拡張子を表示 #default: false

# Network Storage
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true # ネットワークディスクで`.DS_Store`を作らない #default: false
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true     # USBディスクで`.DS_Store`を作らない #default: false

# Cloud Storage
# defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false # ファイル保存デフォルトをローカルに設定 #default: true

# System Folders
chflags nohidden ~/Library && xattr -d com.apple.FinderInfo ~/Library # 「ライブラリ」フォルダを常に表示 #default: hidden

###########################################################
# Mission Control & Spaces
###########################################################

# Hot Corners
# Values: 0=no-op, 2=Mission Control, 3=App windows, 4=Desktop, 5=Start screensaver,
#         6=Disable screensaver, 7=Dashboard, 10=Display sleep, 11=Launchpad, 12=Notification Center
# defaults write com.apple.dock wvous-bl-corner -int 10 # 左下ホットコーナーでディスプレイスリープ #default: 0
# defaults write com.apple.dock wvous-bl-modifier -int 0 # 修飾キーなし #default: 0

# Spaces Behavior
defaults write com.apple.dock mru-spaces -bool false # Spacesを使用頻度で自動並び替え #default: true

# Window Restoration (ログイン時にウィンドウを前回の状態に復元)
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true   # ログイン時に前回のウィンドウを復元 #default: false
defaults write com.apple.loginwindow TALLogoutSavesState -bool true # ログアウト時にアプリケーション状態を保存 #default: false

###########################################################
# Keyboard & Text Input
###########################################################

# Modifier Keys
# Caps Lock を Control に変更する。
# 数値はHID usage code: Src 30064771129 = 0x700000039 (Caps Lock),
#                       Dst 30064771300 = 0x7000000E4 (Control)
# defaults側は再ログイン後に有効。hidutil側は即時反映（再起動で消えるが上のdefaultsが引き継ぐ）
defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
    '{"HIDKeyboardModifierMappingDst"=30064771300;"HIDKeyboardModifierMappingSrc"=30064771129;}'
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E4}]}' >/dev/null 2>&1 || true

# Key Repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false # 長押し文字選択機能 #default: true
defaults write NSGlobalDomain KeyRepeat -int 1                     # キーリピート速度を最高速に #default: 6
defaults write NSGlobalDomain InitialKeyRepeat -int 14             # キーリピート開始までの時間 #default: 25

# Function Keys
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true # 標準ファンクションキー優先モード #default: false

# Text Correction
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false         # 自動スペル修正機能 #default: true
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false # 自動大文字化機能 #default: true
# defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false # ダッシュの自動置換 #default: true
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false # ピリオド自動挿入機能 #default: true
# defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false # 引用符の自動置換 #default: true

# Key Mappings
# CapsLock を Ctrl に変更 (macOS再起動が必要) - JIS以外のキーボードのみ #default: CapsLock
keyboard_id="$(ioreg -c AppleEmbeddedKeyboard -r | grep -Eiw "VendorID|ProductID" | awk '{ print $4 }' | paste -s -d'-\n' -)-0"

# JISキーボードかどうかを判定（入力ソースでJIS配列を検出）
is_jis_keyboard() {
    # 現在の入力ソースまたはキーボード設定からJIS配列を検出
    defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep -q "com.apple.keylayout.Japanese" ||
        system_profiler SPHardwareDataType | grep -q "Japanese"
}

# JIS以外のキーボードの場合のみCapsLock→Ctrl変更を適用
if ! is_jis_keyboard; then
    defaults -currentHost write -g com.apple.keyboard.modifiermapping.${keyboard_id} -array-add "
<dict>
  <key>HIDKeyboardModifierMappingDst</key>\
  <integer>30064771300</integer>\
  <key>HIDKeyboardModifierMappingSrc</key>\
  <integer>30064771129</integer>\
</dict>
"
    echo "✅ CapsLock → Ctrl mapping applied (non-JIS keyboard detected)"
else
    echo "⏭️  CapsLock mapping skipped (JIS keyboard detected)"
fi

# Input Source Switching
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 "<dict><key>enabled</key><false/></dict>" # Ctrl+Space入力ソース切り替え機能 #default: true
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 "<dict><key>enabled</key><false/></dict>" # Ctrl+Opt+Space入力ソース切り替え機能 #default: false

# Shortcuts (Commented)
# defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 27 "..." # 次のウィンドウ操作をOpt+Tabに変更 #default: Cmd+`

###########################################################
# Trackpad & Mouse
###########################################################

# Scroll & Navigation
defaults write -g com.apple.swipescrolldirection -bool false # ナチュラルスクロール #default: true

# Trackpad Gestures
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -bool false # 3本指水平スワイプ機能 #default: true

# Click & Tap
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0  # 第1クリック閾値（軽い） #default: 1
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0 # 第2クリック閾値（軽い） #default: 1
defaults write -g com.apple.trackpad.forceClick -bool false                  # Force Click機能 #default: true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true         # タップでクリック機能 #default: false
defaults write -g com.apple.mouse.tapBehavior -bool true                     # 軽いタップでクリック機能 #default: false

# Tracking Speed
defaults write -g com.apple.trackpad.scaling -float 2.5 # トラックパッドの移動速度 #default: 0.6875
defaults write -g com.apple.mouse.scaling -float 1.5    # マウスの移動速度 #default: 0.6875

# Mouse Settings (Commented)
# defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode TwoButton # Bluetoothマウス2ボタンモード #default: OneButton

###########################################################
# Dock
###########################################################
# Visibility & Animation
defaults write com.apple.dock autohide -bool true             # Dock自動非表示機能 #default: false
defaults write com.apple.dock autohide-delay -float 10000     # Dock自動非表示の遅延時間 #default: 0.5
defaults write com.apple.dock autohide-time-modifier -float 0 # Dock表示・非表示のアニメーション時間 #default: 0.5
defaults write com.apple.dock launchanim -bool false          # アプリ起動バウンドアニメーション #default: true

# Content & Display
defaults write com.apple.dock show-recents -bool false # 最近使用したアプリ表示 #default: true
defaults write com.apple.dock showhidden -bool true    # 隠しアプリ透過表示 #default: false

# Layout & Size (Commented)
# defaults write com.apple.dock orientation -string right # Dockを右側に配置 #default: "bottom"
defaults write com.apple.dock tilesize -int 56 # Dockアイコンサイズ #default: 64
# defaults write com.apple.dock magnification -bool false # Dockマウスオーバー拡大機能 #default: true
defaults write com.apple.dock largesize -int 80 # 拡大時のアイコンサイズ #default: 128

# Window Effects (Commented)
# defaults write com.apple.dock mineffect -string "scale" # ウィンドウ最小化エフェクト #default: "genie"
# defaults write com.apple.dock minimize-to-application -bool true # アプリアイコンに最小化 #default: false

###########################################################
# Finder
###########################################################

# General Settings
defaults write com.apple.finder QuitMenuItem -bool true  # Finder終了メニュー表示 #default: false
defaults write com.apple.finder FinderSounds -bool false # Finder効果音 #default: true

# Desktop & File Display
defaults write com.apple.finder CreateDesktop -bool false    # デスクトップアイコン表示 #default: true
defaults write com.apple.finder AppleShowAllFiles -bool true # 隠しファイル表示 #default: false

# Window Display
defaults write com.apple.finder ShowStatusBar -bool true           # ステータスバーを表示 #default: false
defaults write com.apple.finder ShowPathbar -bool true             # パスバーを表示 #default: false
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true # タイトルバーにフルパスを表示 #default: false

# View & Navigation
defaults write com.apple.finder FXPreferredViewStyle -string "clmv" # デフォルトビューをカラムビューに #default: "icnv"
# View codes: icnv=Icon, clmv=Column, glyv=Gallery, Nlsv=List

# Performance & Animation
defaults write com.apple.finder DisableAllAnimations -bool true # Finderアニメーション効果 #default: false
defaults write com.apple.finder AnimateWindowZoom -bool false   # フォルダを開くアニメーション #default: true

# Volume Mounting
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true # 読み込み専用ディスクイメージの自動展開 #default: false
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true # 読み書き可能ディスクイメージの自動展開 #default: false
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true    # リムーバブルディスク接続時に新しいウィンドウを開く #default: false

# Quick Look
defaults write com.apple.finder QLHidePanelOnDeactivate -bool true # 他ウィンドウ移動時にQuick Lookを非表示 #default: false
defaults write com.apple.finder QLEnableTextSelection -bool true   # Quick Look上でテキスト選択を可能に #default: false

# Desktop Icons (Commented)
# defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true # 外付けHDDをデスクトップに表示 #default: false
# defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true # 内蔵HDDをデスクトップに表示 #default: false
# defaults write com.apple.finder ShowMountedServersOnDesktop -bool true # マウント済みサーバをデスクトップに表示 #default: false
# defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true # リムーバブルメディアをデスクトップに表示 #default: true

# Additional Options (Commented)
# defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false # 拡張子変更の警告 #default: true
# defaults write com.apple.finder WarnOnEmptyTrash -bool false # ゴミ箱を空にする警告 #default: true

###########################################################
# Menu Bar & System UI
###########################################################

# Menu Bar Visibility
# defaults write NSGlobalDomain _HIHideMenuBar -bool true # メニューバー自動非表示 #default: false

# Clock & Time Display
defaults write com.apple.iCal "number of hours displayed" 24 # カレンダーを24時間表示 #default: 12
# defaults write com.apple.menuextra.clock DateFormat -string "M月d日(EEE)  h:mm:ss" # 時計の表示フォーマット (macOS Big Sur以降では動作せず) #default: "EEE MMM d  h:mm:ss a"

# Battery Display
defaults write com.apple.menuextra.battery ShowPercent -string "YES" # バッテリー残量をパーセンテージで表示 #default: "NO"

# Sound (Commented)
# defaults write NSGlobalDomain com.apple.sound.beep.volume -float 0 # システム警告音量を0に設定 #default: 0.6065
# defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool false # 音量変更時の効果音 #default: true

###########################################################
# Applications
###########################################################

# Safari
defaults write com.apple.Safari AutoFillPasswords -bool false # Safariパスワード自動入力機能を停止 #default: true
# defaults write com.apple.Safari IncludeDevelopMenu -bool true # 開発メニューを表示 #default: false
# defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true # Safari開発者ツール表示 #default: false
# defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true # スマート検索フィールドに完全なURLを表示 #default: false

# QuickTime Player
defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindows -bool false # 起動時に前回のファイルを開かない #default: true

# Preview
defaults write com.apple.Preview NSQuitAlwaysKeepsWindows -bool false # Preview: 起動時に前回開いたウィンドウを開かない #default: true

# Hammerspoon
defaults write org.hammerspoon.Hammerspoon MJConfigFile "$HOME/.config/hammerspoon/init.lua" # 設定を ~/.config/hammerspoon/ から読む（XDG準拠） #default: ~/.hammerspoon/init.lua

# TextEdit (Commented)
# defaults write com.apple.TextEdit RichText -int 0 # TextEdit新規文書をプレーンテキストに設定 #default: 1
# defaults write com.apple.TextEdit PlainTextEncoding -int 4 # TextEditプレーンテキストエンコーディングをUTF-8に設定 #default: 0
# defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4 # TextEdit保存時エンコーディングをUTF-8に設定 #default: 0

# Activity Monitor (Commented)
# defaults write com.apple.ActivityMonitor OpenMainWindow -bool true # アクティビティモニタを開くときメインウィンドウを表示 #default: false
# defaults write com.apple.ActivityMonitor IconType -int 5 # Dockアイコンの表示 (5: CPU使用率) #default: 0

###########################################################
# Screenshots & Media
###########################################################

# Screenshot Settings
# defaults write com.apple.screencapture name ScreenShot # スクリーンショットのファイル名 #default: "Screenshot"
defaults write com.apple.screencapture disable-shadow -bool true # スクリーンショットウィンドウの影を非表示 #default: false

# Set screenshot location (Google Drive if mounted, otherwise ~/Screenshot)
#
# ⚠️ ここで設定できるのは「macOS純正の」スクリーンショット機能の保存先だけ。
#    CleanShot Xを使いたい場合、保存先はCleanShot側のGUI設定（Preferences > General）で決める。
#
# アカウントのメールアドレスに依存しないようglobで自動検出する。
# ルート名はGoogle Driveの表示言語で変わるため "My Drive" と "マイドライブ" の両方を見る。
SCREENSHOT_DIR=""
for gdrive_dir in "$HOME/Library/CloudStorage"/GoogleDrive-*; do
    for drive_root in "My Drive" "マイドライブ"; do
        if [ -d "$gdrive_dir/$drive_root" ]; then
            SCREENSHOT_DIR="$gdrive_dir/$drive_root/Screenshot"
            mkdir -p "$SCREENSHOT_DIR"
            break 2
        fi
    done
done
if [ -z "$SCREENSHOT_DIR" ]; then
    SCREENSHOT_DIR="$HOME/Screenshot"
    mkdir -p "$SCREENSHOT_DIR"
    echo "⚠️  Google Drive not mounted - using local folder"
fi
defaults write com.apple.screencapture location "$SCREENSHOT_DIR"
echo "📸 Screenshot location set to: $SCREENSHOT_DIR"
killall SystemUIServer 2>/dev/null || true # スクリーンショット設定を即時反映

# defaults write com.apple.screencapture include-date -bool false # スクリーンショットファイル名から日付除去 #default: true
# defaults write com.apple.screencapture type -string "png" # スクリーンショットの形式 #default: "png"

# Image Capture (Commented)
# defaults write com.apple.ImageCapture disableHotPlug -bool true # イメージキャプチャホットプラグ機能停止 #default: false

###########################################################
# Advanced System Settings (Commented)
###########################################################

# Additional Interface Options
# defaults write NSGlobalDomain AppleAccentColor -int 6 # アクセントカラー (0-7) #default: -1
# defaults write NSGlobalDomain AppleHighlightColor -string "1.000000 0.749020 0.823529 Pink" # ハイライト色 #default: varies
# defaults write NSGlobalDomain AppleAquaColorVariant -int 1 # ボタン・メニューの表示 (1: Blue, 6: Graphite) #default: 1
# defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false # タイトルバーダブルクリックで最小化 #default: true

# Dialog & Panel Behavior
# defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true # 保存ダイアログを詳細表示で開く #default: false
# defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true # 印刷ダイアログを詳細表示で開く #default: false

# Application Termination
# defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true # アプリ自動終了機能停止 #default: false

# Time Machine
# defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true # 新しいディスクをバックアップに提案しない #default: false

###########################################################
# Apply settings
###########################################################
# defaults write は plist を書き換えるだけで、既に起動しているアプリには
# 反映されない。関連プロセスを再起動して即時反映させる。
# （それでもトラックパッド・キーボード等の一部は再ログインが必要）
for app in Dock Finder SystemUIServer; do
    killall "$app" >/dev/null 2>&1 || true
done

echo ""
echo "✅ macOS defaults applied."
echo "ℹ️  NOTE: 一部の設定（トラックパッド・キーボード・Caps Lock等）は"
echo "    再ログインまたは再起動後に有効になります。"
echo "ℹ️  NOTE: Some settings take effect after logout or restart."

###########################################################
# 手動設定が必要な項目 / Manual Configuration Required
###########################################################

# 以下の設定は defaults コマンドでは変更できないため、手動で設定する必要があります。
# The following settings cannot be changed with the defaults command and must be configured manually.

# ====================
# セキュリティとプライバシー / Security & Privacy
# ====================

# FileVault暗号化の有効化
# システム設定 > プライバシーとセキュリティ > FileVault > オンにする
# System Preferences > Privacy & Security > FileVault > Turn On

# Touch ID / Face IDの設定
# システム設定 > Touch ID と パスコード > 指紋を追加
# System Preferences > Touch ID & Passcode > Add Fingerprint

# アプリケーションのプライバシー許可設定
# システム設定 > プライバシーとセキュリティ > プライバシー
# - カメラ、マイク、位置情報、連絡先、カレンダー等のアクセス許可
# System Preferences > Privacy & Security > Privacy
# - Camera, Microphone, Location Services, Contacts, Calendar access permissions

# ファイアウォールの詳細設定
# システム設定 > ネットワーク > ファイアウォール > オプション
# System Preferences > Network > Firewall > Options

# ====================
# ネットワーク設定 / Network Settings
# ====================

# Wi-Fiネットワークの追加・接続
# システム設定 > Wi-Fi > ネットワークを追加
# System Preferences > Wi-Fi > Add Network

# VPN設定の追加
# システム設定 > VPNとデバイス管理 > VPN > VPN構成を追加
# System Preferences > VPN & Device Management > VPN > Add VPN Configuration

# ====================
# ユーザーとグループ / Users & Groups
# ====================

# 新規ユーザーアカウントの作成
# システム設定 > ユーザとグループ > ユーザまたはグループを追加
# System Preferences > Users & Groups > Add User or Group

# ログインオプションの設定
# システム設定 > ユーザとグループ > ログインオプション
# - 自動ログイン、ゲストユーザー、ファストユーザスイッチング等
# System Preferences > Users & Groups > Login Options
# - Automatic login, Guest User, Fast User Switching, etc.

# ====================
# Apple ID と iCloud / Apple ID & iCloud
# ====================

# Apple IDでのサインイン
# システム設定 > Apple IDでサインイン
# System Preferences > Sign in with your Apple ID

# iCloud同期設定
# システム設定 > Apple ID > iCloud
# - メール、連絡先、カレンダー、写真、iCloud Drive等の同期設定
# System Preferences > Apple ID > iCloud
# - Mail, Contacts, Calendar, Photos, iCloud Drive sync settings

# ====================
# ディスプレイとハードウェア / Display & Hardware
# ====================

# 外部ディスプレイの解像度設定
# システム設定 > ディスプレイ > 解像度
# System Preferences > Displays > Resolution

# Bluetooth機器のペアリング
# システム設定 > Bluetooth > デバイスを追加
# System Preferences > Bluetooth > Add Device

# プリンター・スキャナーの追加
# システム設定 > プリンタとスキャナ > プリンタまたはスキャナを追加
# System Preferences > Printers & Scanners > Add Printer or Scanner

# ====================
# アプリケーション設定 / Application Settings
# ====================

# デフォルトアプリケーションの設定（一部）
# Finderでファイルを選択 > 情報を見る > このアプリケーションで開く > すべてを変更
# Select file in Finder > Get Info > Open with > Change All

# ブラウザのデフォルト設定
# 各ブラウザの設定画面から「デフォルトブラウザに設定」
# Set as default browser in each browser's preferences

# ====================
# 詳細なシステム設定 / Advanced System Settings
# ====================

# Spotlight検索結果の詳細設定
# システム設定 > Siri と Spotlight > Spotlight > プライバシー
# System Preferences > Siri & Spotlight > Spotlight > Privacy

# 通知センターのアプリ別設定
# システム設定 > 通知 > 各アプリの通知設定
# System Preferences > Notifications > Per-app notification settings

# ソフトウェアアップデートの自動更新設定
# システム設定 > 一般 > ソフトウェアアップデート > 自動アップデート
# System Preferences > General > Software Update > Automatic Updates

# ====================
# 開発者向け設定 / Developer Settings
# ====================

# 不明な開発者からのアプリの実行許可
# システム設定 > プライバシーとセキュリティ > セキュリティ
# "任意の場所からのアプリケーションを許可" は以下コマンドで有効化可能：
# sudo spctl --master-disable
# System Preferences > Privacy & Security > Security
# Allow apps from anywhere can be enabled with: sudo spctl --master-disable

# Xcodeコマンドラインツールのライセンス同意
# sudo xcodebuild -license accept

# ====================
# その他の推奨設定 / Other Recommended Settings
# ====================

# ホットコーナーの設定
# システム設定 > デスクトップとDock > ホットコーナー
# System Preferences > Desktop & Dock > Hot Corners

# Mission Controlのショートカットキー設定
# システム設定 > キーボード > キーボードショートカット > Mission Control
# System Preferences > Keyboard > Keyboard Shortcuts > Mission Control

# アクセシビリティ機能の設定
# システム設定 > アクセシビリティ
# - ズーム、VoiceOver、スイッチコントロール等
# System Preferences > Accessibility
# - Zoom, VoiceOver, Switch Control, etc.

# ====================
# 注意事項 / Important Notes
# ====================

# 1. 上記の設定は管理者権限が必要な場合があります
# 2. 一部の設定は再起動後に有効になります
# 3. セキュリティ関連の設定は慎重に行ってください
# 4. 企業環境では組織のポリシーに従ってください

# 1. Some settings may require administrator privileges
# 2. Some settings take effect after restart
# 3. Configure security settings carefully
# 4. Follow organizational policies in corporate environments
