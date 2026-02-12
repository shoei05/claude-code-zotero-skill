# Zotero API Endpoints Reference

## 1. ローカル API

Base URL: `http://localhost:23119`

### Connector API（読み書き可能）

POST エンドポイント。Zotero Connector プロトコル。

#### POST /connector/ping

Zotero 起動確認。

```bash
curl -s http://localhost:23119/connector/ping
# => <html>Zotero is running</html>
```

#### POST /connector/getSelectedCollection

Zotero UI で選択中のコレクション情報を取得。

```bash
curl -s -X POST http://localhost:23119/connector/getSelectedCollection \
  -H "Content-Type: application/json" -d '{}'
```

レスポンス: `{ "libraryID": 1, "name": "コレクション名", "id": 29, "targets": [...] }`

#### POST /connector/import

BibTeX/RIS 等をインポート。**Zotero UI で選択中のコレクション**に保存。

```bash
curl -s -X POST "http://localhost:23119/connector/import?session=UNIQUE_ID" \
  -H "Content-Type: application/x-bibtex" \
  --data-binary @file.bib
```

- `session`: **毎回ユニークな値**（重複 → 409 SESSION_EXISTS）
- 成功: `201 Created` + JSON（アイテム配列）
- 対応: BibTeX, RIS, その他 Zotero translator 認識フォーマット

#### POST /connector/saveItems

ブラウザ拡張がメタデータ付きアイテムを保存する際に使用。

#### POST /connector/saveSnapshot

Web ページスナップショットの保存。

### Local API（読み取り専用・GET のみ）

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

---

## 2. REST API (Web API v3)

Base URL: `https://api.zotero.org`

### 認証

```bash
# 推奨
-H "Zotero-API-Key: <key>"

# 代替
-H "Authorization: Bearer <key>"

# 非推奨
?key=<key>
```

API キー取得: https://www.zotero.org/settings/keys

### プレフィックス

`<prefix>` = `/users/<userID>` または `/groups/<groupID>`

### 読み取りエンドポイント（GET）

#### コレクション

```
GET <prefix>/collections                          # コレクション一覧
GET <prefix>/collections/top                       # トップレベル
GET <prefix>/collections/<collectionKey>           # 特定コレクション
GET <prefix>/collections/<collectionKey>/collections  # サブコレクション
```

#### アイテム

```
GET <prefix>/items                                 # 全アイテム
GET <prefix>/items/top                             # トップレベル（添付除外）
GET <prefix>/items/trash                           # ゴミ箱
GET <prefix>/items/<itemKey>                       # 特定アイテム
GET <prefix>/items/<itemKey>/children              # 子アイテム
GET <prefix>/publications/items                    # My Publications
GET <prefix>/collections/<collectionKey>/items     # コレクション内
GET <prefix>/collections/<collectionKey>/items/top # コレクション内トップ
```

#### 保存済み検索

```
GET <prefix>/searches                              # 検索一覧
GET <prefix>/searches/<searchKey>                  # 特定検索
```

#### タグ

```
GET <prefix>/tags                                  # 全タグ
GET <prefix>/tags/<url+encoded+tag>                # 特定タグ
GET <prefix>/items/<itemKey>/tags                  # アイテムのタグ
GET <prefix>/collections/<collectionKey>/tags      # コレクションのタグ
GET <prefix>/items/tags                            # 全アイテムのタグ
GET <prefix>/items/top/tags                        # トップアイテムのタグ
GET <prefix>/items/trash/tags                      # ゴミ箱のタグ
GET <prefix>/collections/<key>/items/tags          # コレクション内アイテムのタグ
GET <prefix>/collections/<key>/items/top/tags      # コレクション内トップのタグ
GET <prefix>/publications/items/tags               # Publications のタグ
```

#### ユーザー・グループ

```
GET /users/<userID>/groups                         # 所属グループ一覧
GET /groups/<groupID>                              # グループ詳細
GET /keys/<key>                                    # API キー情報
GET /keys/current                                  # 現在のキー情報
```

#### その他

```
GET <prefix>/deleted?since=<version>               # 削除済み
GET <prefix>/fulltext?since=<version>              # 全文インデックス更新
GET <prefix>/items/<itemKey>/fulltext              # アイテム全文
```

#### メタデータ（認証不要）

```
GET /schema                                        # API スキーマ
GET /itemTypes                                     # アイテムタイプ一覧
GET /itemFields                                    # フィールド一覧
GET /itemTypeFields?itemType=<type>                # タイプ別フィールド
GET /itemTypeCreatorTypes?itemType=<type>           # タイプ別著者タイプ
GET /creatorFields                                 # 著者フィールド
GET /items/new?itemType=<type>                     # 新規テンプレート
GET /items/new?itemType=attachment&linkMode=<mode>  # 添付テンプレート
```

### 書き込みエンドポイント

#### アイテム

```
POST   <prefix>/items                              # 作成（最大50件）
PUT    <prefix>/items/<itemKey>                     # 全体更新
PATCH  <prefix>/items/<itemKey>                     # 部分更新
DELETE <prefix>/items/<itemKey>                     # 単体削除
DELETE <prefix>/items?itemKey=<k1>,<k2>,...         # 複数削除（最大50件）
```

#### コレクション

```
POST   <prefix>/collections                        # 作成
PUT    <prefix>/collections/<collectionKey>         # 更新
DELETE <prefix>/collections/<collectionKey>         # 単体削除
DELETE <prefix>/collections?collectionKey=<k1>,...  # 複数削除（最大50件）
```

#### 保存済み検索

```
POST   <prefix>/searches                           # 作成
DELETE <prefix>/searches?searchKey=<k1>,<k2>,...    # 複数削除（最大50件）
```

#### タグ

```
DELETE <prefix>/tags?tag=<tag1> || <tag2>           # 一括削除（最大50件）
```

#### 全文テキスト

```
PUT <prefix>/items/<itemKey>/fulltext               # 全文テキスト設定
```

#### ファイルアップロード

```
GET   <prefix>/items/<itemKey>/file                 # ファイル取得
POST  <prefix>/items/<itemKey>/file                 # アップロード認可/登録
PATCH <prefix>/items/<itemKey>/file?algorithm=...   # 差分アップロード
```

#### キー管理

```
DELETE /keys/<key>                                  # API キー削除
```

### 検索クエリパラメータ

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| `q` | 文字列 | 検索キーワード |
| `qmode` | `titleCreatorYear` / `everything` | 検索範囲 |
| `itemType` | タイプ名 | アイテムタイプフィルタ |
| `tag` | タグ名 | タグフィルタ（AND: 複数指定、OR: `\|\|` 区切り、NOT: `-` 接頭辞） |
| `since` | バージョン番号 | 指定バージョン以降の変更 |
| `itemKey` | キー（カンマ区切り） | 特定アイテム取得（最大50） |
| `includeTrashed` | `0` / `1` | ゴミ箱含む |
| `sort` | フィールド名 | ソート基準 |
| `direction` | `asc` / `desc` | ソート方向 |
| `start` | 数値 | オフセット |
| `limit` | 1-100 | 取得件数 |
| `format` | `json` / `atom` / `bib` / `keys` / `versions` | 出力形式 |

### レートリミット

- `Backoff: <seconds>` — サーバー負荷時に付与（成功レスポンスにも）
- `429 Too Many Requests` + `Retry-After: <seconds>` — レート超過
- `503 Service Unavailable` + `Retry-After: <seconds>` — メンテナンス等
- 固定の requests/sec 上限値は非公開

### バッチ制限

- 作成/更新: **最大 50 件/リクエスト**
- 複数削除: **最大 50 件/リクエスト**
- ページング `limit`: 1-100
- `format=keys` / `format=versions`: 制限なし

### 競合制御

```
If-Unmodified-Since-Version: <version>    # 更新・削除時必須
If-None-Match: *                          # 新規ファイルアップロード時
If-Match: <md5>                           # 既存ファイル更新時
Zotero-Write-Token: <token>               # 重複送信防止（12時間キャッシュ）
```

---

## 3. 外部 API

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

---

## 4. Streaming API

WebSocket 経由のリアルタイム通知。

```
wss://stream.zotero.org
```

ライブラリの変更をリアルタイムで受信可能。詳細: https://www.zotero.org/support/dev/web_api/v3/streaming_api
