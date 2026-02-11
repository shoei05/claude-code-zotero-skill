# Zotero Local API Endpoints Reference

Base URL: `http://localhost:23119`

## Connector API（読み書き可能）

POST エンドポイント。Zotero Connector プロトコル。

### POST /connector/ping

Zotero 起動確認。

```bash
curl -s http://localhost:23119/connector/ping
# => <html>Zotero is running</html>
```

### POST /connector/getSelectedCollection

Zotero UI で選択中のコレクション情報を取得。

```bash
curl -s -X POST http://localhost:23119/connector/getSelectedCollection \
  -H "Content-Type: application/json" -d '{}'
```

レスポンス: `{ "libraryID": 1, "name": "コレクション名", "id": 29, "targets": [...] }`

### POST /connector/import

BibTeX/RIS 等をインポート。**Zotero UI で選択中のコレクション**に保存。

```bash
curl -s -X POST "http://localhost:23119/connector/import?session=UNIQUE_ID" \
  -H "Content-Type: application/x-bibtex" \
  --data-binary @file.bib
```

- `session`: **毎回ユニークな値**（重複 → 409 SESSION_EXISTS）
- 成功: `201 Created` + JSON（アイテム配列）
- 対応: BibTeX, RIS, その他 Zotero translator 認識フォーマット

### POST /connector/saveItems

ブラウザ拡張がメタデータ付きアイテムを保存する際に使用。

### POST /connector/saveSnapshot

Web ページスナップショットの保存。

## Local API（読み取り専用・GET のみ）

Zotero Web API v3 互換。

| エンドポイント | 説明 |
|--------------|------|
| `/api/users/0/collections` | 全コレクション一覧 |
| `/api/users/0/collections/top` | トップレベルのみ |
| `/api/users/0/collections/:key` | 特定コレクション詳細 |
| `/api/users/0/collections/:key/collections` | サブコレクション |
| `/api/users/0/collections/:key/items` | コレクション内アイテム |
| `/api/users/0/items` | 全アイテム |
| `/api/users/0/items/:key` | 特定アイテム |
| `/api/users/0/items/top` | 添付ファイル・ノート除外 |
| `/api/users/0/searches` | 保存済み検索 |
| `/api/users/0/searches/:key/items` | 検索結果アイテム |
| `/api/groups/:groupID/...` | グループライブラリ |

## 外部 API

### doi.org Content Negotiation（DOI → BibTeX）

```bash
curl -sL -H "Accept: application/x-bibtex" "https://doi.org/10.1038/s41746-023-00979-5"
```

### CrossRef API（文献検索）

```bash
curl -s "https://api.crossref.org/works?query.bibliographic=著者+タイトル&rows=5"
curl -s "https://api.crossref.org/works?query.bibliographic=検索語&filter=from-pub-date:2025-01-01&rows=5"
```

レスポンス: `message.items[].DOI` から DOI を取得。
