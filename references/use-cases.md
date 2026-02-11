# Zotero スキル ユースケース・活用法

## 目次

1. [文献一括インポート](#1-文献一括インポート)
2. [DOI 不明な文献の検索・登録](#2-doi-不明な文献の検索登録)
3. [Web ページ・ガイドラインの登録](#3-web-ページガイドラインの登録)
4. [コレクション管理](#4-コレクション管理)
5. [文献リストの確認](#5-文献リストの確認)
6. [系統的レビューワークフロー](#6-系統的レビューワークフロー)
7. [参考文献リストからの一括登録](#7-参考文献リストからの一括登録)
8. [重複チェック](#8-重複チェック)

---

## 1. 文献一括インポート

論文のリファレンスリストや検索結果から DOI を集めて一括登録。

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

---

## 2. DOI 不明な文献の検索・登録

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

---

## 3. Web ページ・ガイドラインの登録

学会ガイドラインや Web レポートは `@misc` タイプで:

```bibtex
@misc{APA2025,
  title = {Health advisory on generative AI chatbots},
  author = {{American Psychological Association}},
  year = {2025},
  url = {https://www.apa.org/topics/...},
  note = {Retrieved 2026-02-11}
}
```

---

## 4. コレクション管理

```
/zotero collections              # 一覧表示
/zotero list --collection "名前" # アイテム一覧
```

**インポート先**: Zotero UI で選択中のコレクションに保存される。コレクション指定時は事前に UI で選択。

---

## 5. 文献リストの確認

```
/zotero list
```

出力例:
```
 1. Li (2023) Systematic review and meta-analysis of AI-based...
    npj Digital Medicine
 2. Zhang (2025) Generative AI Mental Health Chatbots...
    Journal of Medical Internet Research
```

---

## 6. 系統的レビューワークフロー

1. **検索・DOI 収集**: PubMed/Scholar → DOI リスト作成
2. **一括インポート**: `/zotero import --file dois.txt --collection "SR - Screening"`
3. **スクリーニング**: Zotero UI で include/exclude に分類
4. **確認**: `/zotero list --collection "SR - Include"`

---

## 7. 参考文献リストからの一括登録

Claude に参考文献テキストを渡して:
1. DOI を自動抽出
2. DOI 不明分は CrossRef API で検索
3. 見つからない文献は手動 BibTeX 生成
4. 一括インポート

---

## 8. 重複チェック

```
/zotero search "キーワード"
```

Zotero 本体にも重複検出あり（ツール > 重複アイテム）。

---

## 技術メモ

| 特徴 | Local API (`/api/...`) | Connector API (`/connector/...`) |
|------|----------------------|-------------------------------|
| メソッド | GET のみ（読み取り専用） | POST（読み書き可能） |
| 認証 | 不要 | 不要（localhost のみ） |

**セッション ID**: 各 `/connector/import` に `?session=<unique>` 必須。
**BibTeX 特殊文字**: `--data-binary @file.bib` でファイル経由送信推奨。
