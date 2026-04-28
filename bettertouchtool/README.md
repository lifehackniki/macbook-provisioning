# BetterTouchTool

BTT の設定（"Default" preset）を `.bttpreset`（JSON）で複数 Mac 間共有する。

BTT 本体の SQLite DB は git 向きでないため、AppleScript 経由でエクスポート／インポートする。

## ファイル

- `default.bttpreset` — BTT の "Default" preset 全体（git 管理）

## 前提

- BTT のアクティブな preset は常に 1 つなので、両 Mac の BTT 設定は **基本的に同じものを共有** する運用になる
- preset には license 情報は含まない（`includeSettings` を付けないので個別管理のまま）

## 運用

### エクスポート（変更を git に反映）

```bash
make bettertouchtool/export
```

→ `bettertouchtool/default.bttpreset` が現在の BTT 設定で上書きされる。

### インポート（git の preset を BTT に反映）

```bash
make bettertouchtool/import
```

→ AppleScript 経由で BTT に preset を読み込ませる。

## ワークフロー

### 初期セットアップ（"正" にする Mac で 1 回だけ）

```bash
make bettertouchtool/export
git add bettertouchtool/default.bttpreset
git commit -m "chore(btt): seed preset"
git push
```

### 新しい Mac へ移行

```bash
# bootstrap で BTT もインストール済みの状態から
make bettertouchtool/import
```

### 日常の更新フロー

**変更したマシン**

```bash
git pull && make bettertouchtool/import   # まず最新を取り込む
# BTT GUI で編集
make bettertouchtool/export
git add bettertouchtool/default.bttpreset
git commit -m "feat(btt): <変更内容>"
git push
```

**もう片方のマシン**

```bash
git pull
make bettertouchtool/import
```

### ルール

**BTT を編集する前に必ず `git pull && make bettertouchtool/import`**。
両 Mac で同時編集すると `.bttpreset` のコンフリクトは手動マージが現実的でなく、片方の変更を捨てる羽目になる。

### コンフリクト時

```bash
git checkout --ours bettertouchtool/default.bttpreset      # 自分の変更を採用
# または
git checkout --theirs bettertouchtool/default.bttpreset    # 相手の変更を採用
git add bettertouchtool/default.bttpreset
git commit
make bettertouchtool/import
```
