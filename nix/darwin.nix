{ pkgs, ... }:

let
  primaryUser = "papicom";
  userHome = "/Users/${primaryUser}";

  # defaultsだけでは永続化できない設定と、実行時に保存先を決める設定
  applyDynamicUserDefaults = pkgs.writeShellScript "apply-dynamic-macos-user-defaults" ''
    # ~/LibraryをFinderで常に表示する。
    /usr/bin/chflags nohidden "${userHome}/Library"
    /usr/bin/xattr -d com.apple.FinderInfo "${userHome}/Library" 2>/dev/null || true

    # Caps LockをControlへ変更する。defaultsは次回ログイン用、hidutilは即時反映用。
    /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
      '{"HIDKeyboardModifierMappingDst"=30064771300;"HIDKeyboardModifierMappingSrc"=30064771129;}'
    /usr/bin/hidutil property --set \
      '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E4}]}' \
      >/dev/null 2>&1 || true

    # Google Driveがマウント済みならその中へ、なければローカルへ保存する。
    screenshotDir=""
    for googleDriveDir in "${userHome}/Library/CloudStorage"/GoogleDrive-*; do
      for driveRoot in "My Drive" "マイドライブ"; do
        if [ -d "$googleDriveDir/$driveRoot" ]; then
          screenshotDir="$googleDriveDir/$driveRoot/Screenshot"
          break 2
        fi
      done
    done
    if [ -z "$screenshotDir" ]; then
      screenshotDir="${userHome}/Screenshot"
    fi
    /bin/mkdir -p "$screenshotDir"
    /usr/bin/defaults write com.apple.screencapture location "$screenshotDir"
  '';
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = primaryUser;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # nix-darwinはデフォルトで/etc/zshrcにcompinitとbashcompinitとpromptを仕込む。
  # zsh-autocompleteは「compinitを一切呼ばないこと」を要求するため衝突する。
  # プロンプトもstarshipで上書きされるだけなので無効化する。
  programs.zsh = {
    enableGlobalCompInit = false;
    enableBashCompletion = false;
    promptInit = "";
  };

  # sudoでTouch IDを使用。pam_reattachでtmux内からの認証にも対応する。
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # 起動音を無効化する
  system.nvram.variables.SystemAudioVolume = "%00";

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 1;
      InitialKeyRepeat = 20;
      "com.apple.keyboard.fnState" = true;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      "com.apple.swipescrolldirection" = false;
      "com.apple.trackpad.forceClick" = false;
      "com.apple.trackpad.scaling" = 2.5;
      AppleShowAllExtensions = true;
    };

    trackpad = {
      Clicking = true;
      FirstClickThreshold = 0;
      SecondClickThreshold = 0;
      TrackpadThreeFingerHorizSwipeGesture = 0;
    };

    dock = {
      autohide = true;
      show-recents = false;
      autohide-delay = 10000.0;
      autohide-time-modifier = 0.0;
      launchanim = false;
      showhidden = true;
      tilesize = 56;
      largesize = 80;
      mru-spaces = false;
    };

    finder = {
      AppleShowAllFiles = true;
      CreateDesktop = false;
      QuitMenuItem = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
      FXPreferredViewStyle = "clmv";
    };

    screencapture.disable-shadow = true;
    controlcenter.BatteryShowPercentage = true;

    CustomUserPreferences = {
      NSGlobalDomain = {
        NSScrollViewRubberbanding = false;
        NSQuitAlwaysKeepsWindows = true;
        "com.apple.mouse.tapBehavior" = true;
        "com.apple.mouse.scaling" = 1.5;
      };

      # 入力ソースの切り替えを Ctrl + Space に割り当てる。
      #
      # parameters は (ASCII, キーコード, 修飾フラグ) の順
      # 32 = Space の ASCII、49 = Space のキーコード、262144 = 0x40000 = Control
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys."60" = {
        enabled = true;
        value = {
          parameters = [ 32 49 262144 ];
          type = "standard";
        };
      };

      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      # universalaccess.reduceMotionはmacOSによって書き込みを拒否されるため、
      # System Settingsが実際に使用するドメインへ設定する。
      "com.apple.Accessibility".ReduceMotionEnabled = true;

      "com.apple.loginwindow".TALLogoutSavesState = true;

      "com.apple.finder" = {
        FinderSounds = false;
        DisableAllAnimations = true;
        AnimateWindowZoom = false;
        OpenWindowForNewRemovableDisk = true;
        QLHidePanelOnDeactivate = true;
        QLEnableTextSelection = true;
      };

      "com.apple.frameworks.diskimages" = {
        auto-open-ro-root = true;
        auto-open-rw-root = true;
      };

      "com.apple.iCal"."number of hours displayed" = 24;
      "com.apple.QuickTimePlayerX".NSQuitAlwaysKeepsWindows = false;
      "com.apple.Preview".NSQuitAlwaysKeepsWindows = false;

      # Hammerspoonの設定は~/.hammerspoonではなくdotfiles配下に置いている。
      "org.hammerspoon.Hammerspoon".MJConfigFile =
        "${userHome}/.config/hammerspoon/init.lua";
    };
  };

  launchd.user.agents.apply-dynamic-macos-user-defaults = {
    serviceConfig = {
      ProgramArguments = [ "${applyDynamicUserDefaults}" ];
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };

  # nix-darwinの互換性基準
  system.stateVersion = 6;
}

