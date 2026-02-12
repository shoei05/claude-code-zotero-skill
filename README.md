# claude-code-zotero-skill

**Claude Code から Zotero を直接操作するスキル** — DOI 一括インポート、コレクション管理、キーワード・著者検索

> macOS (Zotero 8.0.3) で動作確認済み。MCP サーバー不要。追加依存なし。`curl` だけで Zotero ローカル API を直接叩く軽量アプローチ。

---

## 1. ローカル API だけでできること

Zotero が起動していれば、**API キーの取得や外部アカウントの設定は一切不要**で、以下のすべてが使えます。

### できること一覧

| コマンド | 説明 |
|---------|------|
| `/zotero import <DOIs>` | DOI リストから BibTeX を自動取得して一括インポート |
| `/zotero import --file dois.txt` | テキストファイルの DOI を一括インポート |
| `/zotero bibtex file.bib` | BibTeX/RIS ファイルを直接インポート（DOI なし文献対応） |
| `/zotero collections` | コレクション一覧を表示 |
| `/zotero list` | 現在選択中コレクションのアイテム一覧 |
| `/zotero list --collection "名前"` | 指定コレクションのアイテム一覧 |
| `/zotero search "keyword"` | タイトル・著者名・年でキーワード検索 |

**バッチ処理例**: 19 件の DOI を含む参考文献リストを渡すと、DOI 自動抽出 → BibTeX 取得 → CrossRef フォールバック → 手動 BibTeX 生成 → 一括インポートまで自動実行。

### セットアップ（これだけ）

#### 1. Zotero 側の設定

1. Zotero を起動
2. **Zotero > 環境設定 > 詳細**
3. **「Allow other applications on this computer to communicate with Zotero」** にチェック
4. `http://localhost:23119/api/` でアクセス可能になる

#### 2. スキルを配置

```bash
git clone https://github.com/shoei05/claude-code-zotero-skill.git ~/.claude/skills/zotero
```

#### 3. 接続確認

```bash
curl -s http://localhost:23119/connector/ping
# => <html>Zotero is running</html>
```

以上。追加のインストールは不要です。

### 動作環境

| 要件 | 詳細 |
|------|------|
| **OS** | macOS（動作確認済み） |
| **Zotero** | 7 / 8（ローカル API 有効化済み） |
| **Claude Code** | CLI 環境 |
| **システム依存** | `curl`, `python3`, `openssl`（macOS 標準搭載・追加インストール不要） |

### 使い方

#### DOI 一括インポート

```
/zotero import 10.1038/s41746-023-00979-5, 10.2196/78238, 10.1016/j.compedu.2024.105224
```

または DOI リストファイルから:
```
/zotero import --file ~/research/dois.txt
```

**処理フロー**:
1. doi.org に BibTeX をリクエスト（Content Negotiation）
2. 失敗時は CrossRef API にフォールバック
3. Zotero Connector API (`/connector/import`) で現在選択中のコレクションに登録

#### 手動 BibTeX インポート（DOI なし文献）

DOI がない文献（学会ガイドライン、ケースレポート等）:
```
/zotero bibtex /path/to/manual.bib
```

#### キーワード検索

```
/zotero search "AI psychosis"
```

内部的には:
```bash
curl -s "http://localhost:23119/api/users/0/items?q=psychosis&qmode=titleCreatorYear"
```

#### コレクション一覧・アイテム一覧

```
/zotero collections
/zotero list --collection "2602-生成AIとメンタルヘルス"
```

### ローカル API のアーキテクチャ

Zotero は `localhost:23119` で 2 種類のローカル API を公開しています:

```
localhost:23119
├── /api/...          ← Local API（GET のみ・読み取り専用）
│   ├── /users/0/collections
│   ├── /users/0/items
│   └── /users/0/items?q=keyword&qmode=titleCreatorYear
│
└── /connector/...    ← Connector API（POST・読み書き可能）
    ├── /connector/ping
    ├── /connector/import?session=UNIQUE_ID
    └── /connector/getSelectedCollection
```

- **Local API (`/api/...`)** は GET のみ（読み取り専用）
- **Connector API (`/connector/...`)** は POST で読み書き可能
- `/connector/import` の `session` パラメータは**毎回ユニーク**にする（重複で 409 エラー）
- インポート先は **Zotero UI で選択中のコレクション** に保存される

### ユースケース（ローカル API）

#### DOI 一括インポート

```
/zotero import 10.1038/s41746-023-00979-5, 10.2196/78238
/zotero import --file ~/research/dois.txt --collection "My Review"
```

**dois.txt の形式**:
```
# AI and Mental Health papers
10.1038/s41746-023-00979-5
10.2196/78238
https://doi.org/10.1016/j.compedu.2024.105224
```

#### DOI 不明な文献の検索・登録

CrossRef API で検索 → DOI 特定 → インポート。見つからない場合は手動 BibTeX:

```bibtex
@article{Pierre2025,
  title = {Case report title},
  author = {Pierre, Joseph M. and Gaeta, Bryce},
  journal = {Innovations in Clinical Neuroscience},
  volume = {22}, pages = {11-13}, year = {2025}
}
```

```
/zotero bibtex /tmp/paper.bib
```

#### Web ページ・ガイドラインの登録

```bibtex
@misc{APA2025,
  title = {Health advisory on generative AI chatbots},
  author = {{American Psychological Association}},
  year = {2025},
  url = {https://www.apa.org/topics/...},
  note = {Retrieved 2026-02-11}
}
```

#### 系統的レビュー（Systematic Review）ワークフロー

1. **検索・DOI 収集**: PubMed/Scholar → DOI リスト作成
2. **一括インポート**: `/zotero import --file dois.txt`
3. **スクリーニング**: Zotero UI で include/exclude に分類
4. **確認**: `/zotero list --collection "SR - Include"`

#### 参考文献リストからの一括登録

論文の References セクションのテキストを Claude Code に渡すと:
1. DOI を自動抽出
2. DOI 不明分は CrossRef API で検索
3. 見つからない文献は手動 BibTeX 生成
4. 一括インポート実行

### トラブルシューティング（ローカル API）

| 症状 | 原因 | 対処 |
|------|------|------|
| `Local API is not enabled` | 環境設定未設定 | Zotero > 環境設定 > 詳細 > 通信許可にチェック |
| `SESSION_EXISTS` (409) | セッション ID 重複 | 各リクエストにユニーク ID を付与（スクリプトは自動対応） |
| BibTeX 取得失敗 | DOI 未登録 or プレプリント | CrossRef API で正しい DOI を検索 |
| `400` on import | BibTeX パースエラー | `--data-binary @file.bib` でファイル経由送信 |

---

## 2. API キーを取得するとできること（REST API）

ローカル API だけでも日常的な文献管理は十分ですが、**Zotero の API キー**を取得すると、さらに以下のことが可能になります。

### ローカル API ではできない、REST API で広がる機能

| 機能 | 説明 |
|------|------|
| **コレクション作成** | CLI からコレクションを新規作成・名前変更・削除 |
| **アイテムの直接作成** | JSON でアイテムを作成（BibTeX 経由ではなく直接、最大50件/リクエスト） |
| **アイテムの更新・削除** | タイトル変更、タグ追加、メタデータ修正、アイテム削除 |
| **タグの一括操作** | 不要タグの一括削除 |
| **添付ファイルアップロード** | PDF 等をクラウドにアップロード |
| **グループライブラリ** | 共同研究グループの文献管理 |
| **Zotero 未起動でも操作** | クラウド API なのでアプリ不要 |
| **リモートからのアクセス** | SSH 先やサーバーからでも操作可能 |

### API キーの取得方法

1. https://www.zotero.org/settings/keys にアクセス
2. **「Create new private key」** をクリック
3. 設定:
   - **Key Description**: 識別名（例: `claude-code-skill`）
   - **Allow library access**: チェック
   - **Allow write access**: チェック（コレクション作成・アイテム追加に必要）
   - **Default Group Permissions**: グループを使う場合は `Read/Write`
4. **「Save Key」** → API キーが生成される

同じページの上部に **User ID** も表示されます:
```
Your userID for use in API calls is XXXXXXX
```

#### 環境変数の設定

```bash
# ~/.zshrc や ~/.bashrc に追加
export ZOTERO_API_KEY="your_api_key_here"
export ZOTERO_USER_ID="your_user_id_here"
```

```bash
source ~/.zshrc
```

#### 接続テスト

```bash
curl -s -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  "https://api.zotero.org/keys/current" | python3 -m json.tool
```

### REST API の使い方

#### 認証

すべてのリクエストに API キーを付与:

```bash
-H "Zotero-API-Key: $ZOTERO_API_KEY"     # 推奨
-H "Authorization: Bearer $ZOTERO_API_KEY" # 代替
```

公開ライブラリの読み取りのみ認証不要。

#### コレクション作成

```bash
curl -s -X POST \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/collections" \
  -d '[{"name": "260212-文献チェック"}]'
```

サブコレクション:
```bash
curl -s -X POST \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/collections" \
  -d '[{"name": "サブコレクション", "parentCollection": "PARENT_KEY"}]'
```

#### アイテム作成

```bash
curl -s -X POST \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items" \
  -d '[{
    "itemType": "journalArticle",
    "title": "AI and Mental Health: A Systematic Review",
    "creators": [{"creatorType": "author", "firstName": "John", "lastName": "Doe"}],
    "date": "2025",
    "DOI": "10.1234/example",
    "collections": ["COLLECTION_KEY"],
    "tags": [{"tag": "AI"}, {"tag": "mental-health"}]
  }]'
```

#### アイテム部分更新（タグ追加など）

```bash
curl -s -X PATCH \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  -H "If-Unmodified-Since-Version: $VERSION" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items/ITEM_KEY" \
  -d '{"tags": [{"tag": "AI"}, {"tag": "reviewed"}]}'
```

#### 検索

```bash
# キーワード検索
curl -s -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items?q=psychosis&qmode=titleCreatorYear"

# タグでフィルタ（AND: 複数 tag、OR: || 区切り、NOT: - 接頭辞）
curl -s -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items?tag=AI&tag=mental-health"
```

#### グループライブラリ

すべてのエンドポイントは `/users/<userID>` を `/groups/<groupID>` に置き換えるだけ:

```bash
# 所属グループ一覧
curl -s -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/groups"

# グループのアイテム取得
curl -s -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  "https://api.zotero.org/groups/GROUP_ID/items"
```

#### アイテム・コレクション削除

```bash
# 単体削除
curl -s -X DELETE \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "If-Unmodified-Since-Version: $VERSION" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items/ITEM_KEY"

# 複数削除（最大50件）
curl -s -X DELETE \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "If-Unmodified-Since-Version: $VERSION" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items?itemKey=KEY1,KEY2,KEY3"
```

#### 添付ファイルアップロード

3段階のフロー:

```bash
# 1. 添付アイテム作成
curl -s -X POST \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items" \
  -d '[{
    "itemType": "attachment",
    "parentItem": "PARENT_ITEM_KEY",
    "linkMode": "imported_file",
    "title": "paper.pdf",
    "contentType": "application/pdf",
    "filename": "paper.pdf"
  }]'

# 2. アップロード認可取得
curl -s -X POST \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "If-None-Match: *" \
  "https://api.zotero.org/users/$ZOTERO_USER_ID/items/ATTACHMENT_KEY/file" \
  -d "md5=$(md5 -q paper.pdf)&filename=paper.pdf&filesize=$(stat -f%z paper.pdf)&mtime=$(stat -f%m paper.pdf)000"

# 3. 認可レスポンスの url にファイル本体を POST → upload 登録
```

### REST API の知っておくべきこと

#### バッチ制限

| 操作 | 上限 |
|------|------|
| 1リクエストでの作成/更新 | **最大 50 件** |
| 1リクエストでの複数削除 | **最大 50 件** |
| ページング `limit` | 1-100（デフォルト 25） |

#### 競合制御

更新・削除時は**バージョン指定が必須**:

```bash
-H "If-Unmodified-Since-Version: <version>"
# バージョン不一致 → 412 Precondition Failed
# バージョン未指定 → 428 Precondition Required
```

#### レートリミット

固定の requests/sec 上限は非公開。以下のレスポンスに注意:

| レスポンス | 対処 |
|-----------|------|
| `Backoff: <seconds>` ヘッダー | 指定秒数待つ |
| `429 Too Many Requests` | `Retry-After` の秒数待つ |
| `503 Service Unavailable` | `Retry-After` の秒数待つ |

### トラブルシューティング（REST API）

| 症状 | 原因 | 対処 |
|------|------|------|
| `403 Forbidden` | API キーの権限不足 | https://www.zotero.org/settings/keys で権限確認 |
| `412 Precondition Failed` | バージョン競合 | 最新バージョンを取得してリトライ |
| `428 Precondition Required` | バージョンヘッダー未指定 | 更新/削除時は `If-Unmodified-Since-Version` 必須 |
| `429 Too Many Requests` | レート制限超過 | `Retry-After` ヘッダーの秒数待つ |

---

## REST API エンドポイント一覧

詳細は [references/api-endpoints.md](references/api-endpoints.md) を参照。

`<prefix>` = `/users/<userID>` または `/groups/<groupID>`

### 読み取り（GET）

| エンドポイント | 説明 |
|--------------|------|
| `<prefix>/collections` | コレクション一覧 |
| `<prefix>/collections/top` | トップレベルコレクション |
| `<prefix>/collections/<key>` | 特定コレクション |
| `<prefix>/items` | 全アイテム |
| `<prefix>/items/top` | トップレベルアイテム |
| `<prefix>/items/<key>` | 特定アイテム |
| `<prefix>/items/<key>/children` | 子アイテム（添付/ノート） |
| `<prefix>/searches` | 保存済み検索一覧 |
| `<prefix>/tags` | タグ一覧 |
| `/users/<id>/groups` | 所属グループ一覧 |
| `/keys/current` | 現在の API キーの権限 |

### 書き込み（POST / PUT / PATCH / DELETE）

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `<prefix>/items` | POST | アイテム作成（最大50件） |
| `<prefix>/items/<key>` | PUT / PATCH | アイテム更新 |
| `<prefix>/items/<key>` | DELETE | アイテム削除 |
| `<prefix>/collections` | POST | コレクション作成 |
| `<prefix>/collections/<key>` | PUT / DELETE | コレクション更新/削除 |
| `<prefix>/searches` | POST | 保存済み検索作成 |
| `<prefix>/tags?tag=...` | DELETE | タグ一括削除 |
| `<prefix>/items/<key>/file` | POST / PATCH | ファイルアップロード |

### メタデータ（認証不要）

| エンドポイント | 説明 |
|--------------|------|
| `/itemTypes` | アイテムタイプ一覧 |
| `/items/new?itemType=<type>` | 新規アイテムテンプレート |
| `/itemTypeFields?itemType=<type>` | タイプ別フィールド |
| `/schema` | API スキーマ |

---

## ZoteroMCP との違い

| | **本スキル（直接 API）** | **ZoteroMCP** |
|---|---|---|
| **対象** | Claude Code（CLI） | Claude Desktop（GUI） |
| **依存関係** | なし（`curl` + `python3` のみ） | Node.js + pip/uv でサーバーインストール |
| **アーキテクチャ** | Zotero HTTP API を直接 `curl` で呼ぶ | MCP サーバープロセスを常駐 |
| **セットアップ** | スキルフォルダを配置するだけ | `pip install` + JSON 設定ファイル編集 |
| **書き込み** | Connector API + REST API | Local API or Web API 経由 |
| **オフライン** | 完全対応（DOI 取得以外） | ローカル API モードで対応 |
| **バッチ処理** | DOI リスト一括インポートスクリプト付き | 個別操作 |

## ファイル構成

```
~/.claude/skills/zotero/
├── SKILL.md                        # スキル定義（Claude Code が読み込む）
├── README.md                       # このファイル
├── scripts/
│   └── zotero_import.sh            # DOI/BibTeX インポートスクリプト
└── references/
    └── api-endpoints.md             # API エンドポイント詳細リファレンス
```

## 参考リンク

- **Zotero Web API v3 公式ドキュメント**: https://www.zotero.org/support/dev/web_api/v3/
  - [Basics](https://www.zotero.org/support/dev/web_api/v3/basics) — エンドポイント一覧、認証、検索パラメータ
  - [Write Requests](https://www.zotero.org/support/dev/web_api/v3/write_requests) — CRUD 操作、バッチ制限
  - [File Upload](https://www.zotero.org/support/dev/web_api/v3/file_upload) — 添付ファイルアップロード
  - [Full-Text Content](https://www.zotero.org/support/dev/web_api/v3/fulltext_content) — 全文インデックス
  - [Syncing](https://www.zotero.org/support/dev/web_api/v3/syncing) — 同期プロトコル
  - [Streaming API](https://www.zotero.org/support/dev/web_api/v3/streaming_api) — WebSocket リアルタイム通知
- **API キー管理**: https://www.zotero.org/settings/keys

## ライセンス

MIT
