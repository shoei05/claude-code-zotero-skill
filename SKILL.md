---
name: zotero
description: >
  Zotero ローカル API 連携スキル。DOI からの文献一括インポート、コレクション管理、アイテム検索・一覧表示を行う。
  Use when: (1) DOI リストから Zotero に文献を登録する, (2) Zotero のコレクション一覧・アイテム一覧を取得する,
  (3) BibTeX/RIS データを Zotero にインポートする, (4) CrossRef API で文献の DOI を検索する。
  Triggers: "zotero", "文献登録", "DOI インポート", "コレクション", "論文追加", "文献管理"
---

# Zotero Local API Skill

Zotero のローカル HTTP サーバー（`localhost:23119`）経由で文献管理操作を行う。

## 前提条件

Zotero が起動中で、以下の設定が有効であること：
- Zotero > 環境設定 > 詳細 > 「Allow other applications on this computer to communicate with Zotero」にチェック

接続確認:
```bash
curl -s http://localhost:23119/connector/ping
```

## コマンド

### 1. DOI 一括インポート (`/zotero import`)

```
/zotero import <DOI1> <DOI2> ...
/zotero import --file <doi_list.txt>
/zotero import --collection "コレクション名"
```

インポートスクリプト:
```bash
bash ~/.claude/skills/zotero/scripts/zotero_import.sh --dois "10.1038/xxx,10.2196/yyy" [--collection "名前"]
```

処理フロー:
1. Zotero 起動確認（`/connector/ping`）
2. 対象コレクション特定（指定なければ現在選択中を使用）
3. 各 DOI → `doi.org` から BibTeX 取得（失敗時 CrossRef フォールバック）
4. `/connector/import?session=<unique_id>` に POST
5. 結果サマリー表示

### 2. 手動 BibTeX インポート (`/zotero bibtex`)

DOI のない文献用。BibTeX ファイルを直接インポート:
```bash
bash ~/.claude/skills/zotero/scripts/zotero_import.sh --bibtex /path/to/file.bib
```

DOI 不明時は CrossRef API で検索:
```bash
curl -s "https://api.crossref.org/works?query.bibliographic=著者名+キーワード&rows=5"
```

### 3. コレクション一覧 (`/zotero collections`)

```bash
curl -s http://localhost:23119/api/users/0/collections | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    d = c['data']
    print(f\"{d['key']}  {d['name']}\")"
```

### 4. アイテム一覧 (`/zotero list`)

```
/zotero list                          # 現在選択中コレクション
/zotero list --collection "名前"      # 指定コレクション
```

### 5. アイテム検索 (`/zotero search`)

```
/zotero search "AI psychosis"
```

## API 概要

| エンドポイント | メソッド | 用途 |
|--------------|---------|------|
| `/connector/ping` | GET/POST | 起動確認 |
| `/connector/import?session=ID` | POST | BibTeX/RIS インポート |
| `/connector/getSelectedCollection` | POST | 選択中コレクション |
| `/api/users/0/collections` | GET | コレクション一覧 |
| `/api/users/0/collections/:key/items` | GET | アイテム一覧 |
| `/api/users/0/items` | GET | 全アイテム |

詳細: [references/api-endpoints.md](references/api-endpoints.md)
ユースケース: [references/use-cases.md](references/use-cases.md)

## 重要な注意点

- **Local API (`/api/...`)** は GET のみ（読み取り専用）
- **Connector API (`/connector/...`)** は POST で読み書き可能
- `/connector/import` の `session` パラメータは**毎回ユニーク**にする（重複で 409 エラー）
- BibTeX にシェル特殊文字がある場合は `--data-binary @file.bib` でファイル経由送信
- インポート先は **Zotero UI で選択中のコレクション** に保存される
