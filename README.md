# claude-code-zotero-skill

**Claude Code から Zotero を直接操作するスキル** — DOI 一括インポート、コレクション管理、キーワード・著者検索

> macOS (Zotero 8.0.3) で動作確認済み。MCP サーバー不要。追加依存なし。`curl` だけで Zotero ローカル API を直接叩く軽量アプローチ。

## できること

| コマンド | 説明 |
|---------|------|
| `/zotero import <DOIs>` | DOI リストから BibTeX を自動取得して一括インポート |
| `/zotero import --file dois.txt` | テキストファイルの DOI を一括インポート |
| `/zotero bibtex file.bib` | BibTeX/RIS ファイルを直接インポート（DOI なし文献対応） |
| `/zotero collections` | コレクション一覧を表示 |
| `/zotero list` | 現在選択中コレクションのアイテム一覧 |
| `/zotero list --collection "名前"` | 指定コレクションのアイテム一覧 |
| `/zotero search "keyword"` | タイトル・著者名・年でキーワード検索 |
| `/zotero search "著者名"` | 著者名で文献検索 |

**バッチ処理例**: 19 件の DOI を含む参考文献リストを渡すと、DOI 自動抽出 → BibTeX 取得 → CrossRef フォールバック → 手動 BibTeX 生成 → 一括インポートまで自動実行。

## 動作環境

| 要件 | 詳細 |
|------|------|
| **OS** | macOS（動作確認済み） |
| **Zotero** | 7 / 8（ローカル API 有効化済み） |
| **Claude Code** | CLI 環境 |
| **システム依存** | `curl`, `python3`, `openssl`（macOS 標準搭載・追加インストール不要） |

Python は標準ライブラリ（`json`, `sys`）のみ使用。`requirements.txt` は不要です。

## セットアップ

### 1. Zotero 側の設定

1. Zotero を起動
2. **Zotero > 環境設定 > 詳細**
3. **「Allow other applications on this computer to communicate with Zotero」** にチェック
4. `http://localhost:23119/api/` でアクセス可能になる

### 2. スキルの配置

```bash
git clone https://github.com/shoei05/claude-code-zotero-skill.git ~/.claude/skills/zotero
```

以上。追加のインストールは不要です。

## 使い方

### DOI 一括インポート

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

### 手動 BibTeX インポート（DOI なし文献）

DOI がない文献（学会ガイドライン、ケースレポート等）:
```
/zotero bibtex /path/to/manual.bib
```

### キーワード検索

```
/zotero search "AI psychosis"
```

内部的には:
```bash
curl -s "http://localhost:23119/api/users/0/items?q=psychosis&qmode=titleCreatorYear"
```

### 著者名検索

```
/zotero search "Keshavan"
```

`qmode=titleCreatorYear` により、タイトル・著者名・年で横断検索。

### コレクション一覧

```
/zotero collections
```

### コレクション内アイテム一覧

```
/zotero list --collection "2602-生成AIとメンタルヘルス"
```

## ZoteroMCP との違い

[ZoteroMCP](https://github.com/54yyyu/zotero-mcp) は Claude Desktop 向けの MCP サーバーとして Zotero を操作しますが、本スキルは異なるアプローチを取っています。

| | **本スキル（直接 API）** | **ZoteroMCP** |
|---|---|---|
| **対象** | Claude Code（CLI） | Claude Desktop（GUI） |
| **依存関係** | なし（`curl` + `python3` のみ） | Node.js + pip/uv でサーバーインストール |
| **アーキテクチャ** | Zotero HTTP API を直接 `curl` で呼ぶ | MCP サーバープロセスを常駐 |
| **セットアップ** | スキルフォルダを配置するだけ | `pip install` + JSON 設定ファイル編集 |
| **書き込み** | Connector API (`/connector/import`) で BibTeX/RIS インポート | Local API or Web API 経由 |
| **全文検索** | `?q=keyword&qmode=titleCreatorYear` で対応 | 全文検索対応 |
| **オフライン** | 完全対応（DOI 取得以外） | ローカルAPI モードで対応 |
| **バッチ処理** | DOI リスト一括インポートスクリプト付き | 個別操作 |

### 直接 API アプローチの利点

1. **ゼロ依存**: MCP サーバーのインストール・起動・管理が不要。`curl` と `python3`（macOS 標準）だけで動作
2. **透過的**: すべての操作が `curl` コマンドに帰着するため、デバッグが容易で何が起きているか明確
3. **バッチ処理特化**: 19 件の DOI を一括インポートするような大量操作に最適化されたスクリプト付き
4. **Claude Code ネイティブ**: CLI 環境でシームレスに動作。`/zotero import` で即実行
5. **軽量**: 常駐プロセスなし。使うときだけ API を叩き、終わったら何も残らない
6. **カスタマイズ容易**: シェルスクリプトなので、ワークフローに合わせた改変が簡単

## API アーキテクチャ

Zotero は `localhost:23119` で 2 種類の API を公開しています:

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

**重要**: Local API は読み取り専用。書き込み（インポート）は Connector API の `/connector/import` を使用。

### セッション管理

`/connector/import` は `?session=<ID>` パラメータが必須。同一 ID の再利用は `409 SESSION_EXISTS` エラーになるため、毎回ユニーク ID を生成:

```bash
SESSION_ID="import-$(date +%s)-$(openssl rand -hex 4)"
```

### DOI → BibTeX 変換

```bash
# doi.org の Content Negotiation
curl -sL -H "Accept: application/x-bibtex" "https://doi.org/10.1038/s41746-023-00979-5"

# CrossRef API でフリーテキスト検索（DOI 不明時）
curl -s "https://api.crossref.org/works?query.bibliographic=著者名+タイトル&rows=5"
```

## ファイル構成

```
~/.claude/skills/zotero/
├── SKILL.md                        # スキル定義（Claude Code が読み込む）
├── README.md                       # このファイル
├── scripts/
│   └── zotero_import.sh            # DOI/BibTeX インポートスクリプト
└── references/
    ├── api-endpoints.md             # API エンドポイント詳細リファレンス
    └── use-cases.md                 # ユースケース・活用ガイド
```

## ユースケース

### 系統的レビュー（Systematic Review）

1. PubMed/Google Scholar で文献検索
2. DOI をテキストファイルに収集
3. `/zotero import --file dois.txt` で一括登録
4. Zotero UI でスクリーニング（include/exclude コレクション分け）
5. `/zotero list --collection "SR - Include"` で選択文献確認

### 参考文献リストからの一括登録

論文の References セクションのテキストを Claude Code に渡すと:
1. DOI を自動抽出
2. DOI 不明分は CrossRef API で検索
3. 見つからない文献は手動 BibTeX 生成
4. 一括インポート実行

### Web ガイドライン・非論文文献の登録

```bibtex
@misc{APA2025,
  title = {Health advisory on generative AI chatbots},
  author = {{American Psychological Association}},
  year = {2025},
  url = {https://www.apa.org/topics/...}
}
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `Local API is not enabled` | 環境設定未設定 | Zotero > 環境設定 > 詳細 > 通信許可にチェック |
| `SESSION_EXISTS` (409) | セッション ID 重複 | 各リクエストにユニーク ID を付与（スクリプトは自動対応） |
| BibTeX 取得失敗 | DOI 未登録 or プレプリント | CrossRef API で正しい DOI を検索 |
| `400` on import | BibTeX パースエラー | `--data-binary @file.bib` でファイル経由送信 |

## ライセンス

MIT
