# macbook-provisioning

macOS の環境構築を自動化するプロビジョニングリポジトリ。Homebrew、各種ツール設定、エディタ拡張などを一括管理する

## セットアップ

新しい Mac でターミナルを開いて、これだけ:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/lifehackniki/macbook-provisioning/main/bootstrap.sh)"
```

このスクリプトが以下を自動で行います:

1. Xcode Command Line Tools
2. Homebrew
3. リポジトリのクローン (`~/ghq/github.com/lifehackniki/macbook-provisioning`)
4. Homebrew パッケージ・Cask・MAS アプリ・VSCode 拡張のインストール
5. 設定ファイルのシンボリックリンク作成
6. yazi プラグインのインストール
7. macOS システム設定の適用

## コマンド一覧

### パッケージ管理

| コマンド | 説明 |
|---|---|
| `make package/install` | Brewfile からパッケージインストール |
| `make package/dump` | 現在のパッケージを Brewfile に書き出し |
| `make package/check` | Brewfile との差分確認 |
| `make package/cleanup` | 不要パッケージ削除 |
| `make npm/install` | グローバル npm パッケージインストール |
| `make yazi/install` | yazi プラグインインストール |
| `make bettertouchtool/export` | 現在の BTT 設定を `bettertouchtool/default.bttpreset` に書き出し |
| `make bettertouchtool/import` | リポジトリの BTT preset を BTT に流し込み |

### 設定ファイルのリンク

| コマンド | 説明 |
|---|---|
| `make link` | 全設定をリンク（下記すべて実行） |
| `make link/home` | `~/` 直下にリンク（zshrc, gitconfig, vimrc, aerospace.toml, tmux.conf, bin/） |
| `make link/config` | `~/.config/` 配下にリンク（ghostty, borders, karabiner, peco, yazi, lazygit） |
| `make copy/claude` | `~/.claude/` へ設定をコピー |
| `make unlink` | リンク解除 |

### macOS システム設定

```bash
bash macos/defaults.sh  # macOS のシステム設定を適用（要再起動）
```

## ディレクトリ構成

```
.
├── bootstrap.sh          # ワンライナーセットアップスクリプト
├── Brewfile              # Homebrew パッケージ定義（VSCode/Cursor 拡張含む）
├── Makefile              # プロビジョニングタスク
├── zsh/                  # ~/.zshrc
├── git/                  # ~/.gitconfig
├── vim/                  # ~/.vimrc
├── tmux/                 # ~/.tmux.conf
├── ghostty/              # ~/.config/ghostty/config
├── aerospace/            # ~/.aerospace.toml
├── borders/              # ~/.config/borders/bordersrc
├── karabiner/            # ~/.config/karabiner/karabiner.json
├── peco/                 # ~/.config/peco/config.json
├── yazi/                 # ~/.config/yazi/*
├── lazygit/              # ~/.config/lazygit/config.yml
├── claude/               # ~/.claude/*
├── bettertouchtool/      # BTT preset（トラックパッド・キーボード）
├── npm/                  # グローバル npm パッケージ一覧
├── macos/                # macOS 設定スクリプト
└── bin/                  # ユーティリティスクリプト（takt, mdview）
```

## 手動インストールが必要なアプリ

- [InYourFace](https://inyourface.app/) - カレンダー通知アプリ
