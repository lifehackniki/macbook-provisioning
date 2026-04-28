# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
CLAUDE.mdを治す場合は指示がない限りは claude/CLAUDE.mdを指します。

## リポジトリ概要

macOS の環境構築を自動化するプロビジョニングリポジトリ。Homebrew、各種ツール設定、VSCode 拡張などを管理する。

## コマンド

### 初期セットアップ（新規 Mac）
```bash
make setup              # Homebrew インストール
make package/install    # brew bundle でパッケージインストール
make link               # 設定ファイルのシンボリックリンク作成
```

### パッケージ管理
```bash
make package/install    # Brewfile からパッケージインストール
make package/dump       # 現在のパッケージを Brewfile に書き出し
make package/check      # Brewfile との差分確認
make package/cleanup    # 不要パッケージ削除
```

### 設定ファイルのリンク
```bash
make link               # 全設定をリンク
make link/home          # ~/直下にリンク（zshrc, gitconfig, vimrc）
make link/config        # ~/.config/配下にリンク（ghostty, borders, karabiner, peco, yazi）
make link/claude        # ~/.claude/配下にリンク
make unlink             # リンク解除
```

### yaziプラグイン管理
```bash
make yazi/install       # yaziプラグインをインストール（ya packコマンド使用）
```

### BetterTouchTool
```bash
make bettertouchtool/export  # 現在のBTT設定をbettertouchtool/default.bttpresetに書き出し
make bettertouchtool/import  # リポジトリのpresetをBTTに流し込み
```
AppleScript経由で自動化。詳細は `bettertouchtool/README.md`。

### macOS システム設定
```bash
bash macos/defaults.sh  # macOS のシステム設定を適用（要再起動）
```

## アーキテクチャ

```
├── Brewfile            # Homebrew パッケージ定義（VSCode/Cursor 拡張含む）
├── Makefile            # プロビジョニングタスク（link/unlink/package管理）
│
├── zsh/                # ~/.zshrc
├── git/                # ~/.gitconfig
├── vim/                # ~/.vimrc
├── ghostty/            # ~/.config/ghostty/config
├── borders/            # ~/.config/borders/bordersrc
├── karabiner/          # ~/.config/karabiner/karabiner.json
├── peco/               # ~/.config/peco/config.json
├── yazi/               # ~/.config/yazi/*
├── claude/             # ~/.claude/*
├── macos/              # macOS設定スクリプト
│
├── bin/                # ユーティリティスクリプト
└── docs/               # セットアップドキュメント
```

