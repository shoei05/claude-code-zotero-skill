#!/bin/bash
# zotero_import.sh - Zotero ローカル API 経由で文献をインポート
#
# Usage:
#   zotero_import.sh --dois "10.1038/xxx,10.2196/yyy"
#   zotero_import.sh --dois "10.1038/xxx" --collection "コレクション名"
#   zotero_import.sh --file dois.txt
#   zotero_import.sh --bibtex references.bib

set -euo pipefail

ZOTERO_URL="http://localhost:23119"
DOIS=""
DOI_FILE=""
BIBTEX_FILE=""
COLLECTION_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dois) DOIS="$2"; shift 2 ;;
    --file) DOI_FILE="$2"; shift 2 ;;
    --bibtex) BIBTEX_FILE="$2"; shift 2 ;;
    --collection) COLLECTION_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Check Zotero ---
PING=$(curl -s --max-time 5 "$ZOTERO_URL/connector/ping" 2>/dev/null || true)
if ! echo "$PING" | grep -q "Zotero"; then
  echo "ERROR: Zotero is not running or local API is not enabled."
  echo "  1. Launch Zotero"
  echo "  2. Preferences > Advanced > Enable 'Allow other applications to communicate'"
  exit 1
fi
echo "OK: Zotero is running"

# --- Show target collection ---
if [[ -n "$COLLECTION_NAME" ]]; then
  echo "Note: Select '$COLLECTION_NAME' in Zotero UI before import."
fi

SELECTED=$(curl -s -X POST "$ZOTERO_URL/connector/getSelectedCollection" \
  -H "Content-Type: application/json" -d '{}' 2>/dev/null)
CURRENT_NAME=$(echo "$SELECTED" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name','(library root)'))" 2>/dev/null)
echo "Target collection: $CURRENT_NAME"

# --- BibTeX file import ---
if [[ -n "$BIBTEX_FILE" ]]; then
  if [[ ! -f "$BIBTEX_FILE" ]]; then
    echo "ERROR: File not found: $BIBTEX_FILE"; exit 1
  fi
  SESSION_ID="import-bib-$(date +%s)-$(openssl rand -hex 4)"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "$ZOTERO_URL/connector/import?session=$SESSION_ID" \
    -H "Content-Type: application/x-bibtex" \
    --data-binary "@$BIBTEX_FILE" 2>/dev/null)
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  if [[ "$HTTP_CODE" == "201" ]]; then
    BODY=$(echo "$RESPONSE" | sed '$d')
    COUNT=$(echo "$BODY" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    echo "SUCCESS: Imported $COUNT item(s) from $BIBTEX_FILE"
  else
    echo "FAIL: HTTP $HTTP_CODE"; echo "$RESPONSE" | sed '$d'
  fi
  exit 0
fi

# --- Build DOI list ---
DOI_LIST=()
if [[ -n "$DOIS" ]]; then
  IFS=',' read -ra DOI_LIST <<< "$DOIS"
fi
if [[ -n "$DOI_FILE" ]]; then
  [[ ! -f "$DOI_FILE" ]] && echo "ERROR: File not found: $DOI_FILE" && exit 1
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    doi=$(echo "$line" | grep -oE '10\.[0-9]{4,}[^ ]*' | head -1)
    [[ -n "$doi" ]] && DOI_LIST+=("$doi")
  done < "$DOI_FILE"
fi

if [[ ${#DOI_LIST[@]} -eq 0 ]]; then
  echo "ERROR: No DOIs specified. Use --dois, --file, or --bibtex"; exit 1
fi

echo "Processing ${#DOI_LIST[@]} DOI(s)..."
echo ""

SUCCESS=0; FAIL=0; FAILED_ITEMS=()

for doi in "${DOI_LIST[@]}"; do
  doi=$(echo "$doi" | xargs)
  echo "--- DOI: $doi ---"

  BIBTEX=$(curl -sL --max-time 15 -H "Accept: application/x-bibtex" "https://doi.org/$doi" 2>/dev/null)

  if [[ -z "$BIBTEX" ]] || echo "$BIBTEX" | grep -q "<!DOCTYPE\|Resource not found\|404\|DOI Not Found"; then
    echo "  doi.org failed, trying CrossRef..."
    BIBTEX=$(curl -sL --max-time 15 -H "Accept: application/x-bibtex" "https://data.crossref.org/$doi" 2>/dev/null)
  fi

  if [[ -z "$BIBTEX" ]] || echo "$BIBTEX" | grep -q "<!DOCTYPE\|Resource not found\|404"; then
    echo "  FAIL: Could not fetch BibTeX"
    FAIL=$((FAIL + 1)); FAILED_ITEMS+=("$doi"); continue
  fi

  echo "  BibTeX: ${#BIBTEX} bytes"

  TMPBIB=$(mktemp /tmp/zotero_bib_XXXXXX.bib)
  echo "$BIBTEX" > "$TMPBIB"

  SESSION_ID="import-$(date +%s)-$(openssl rand -hex 4)"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "$ZOTERO_URL/connector/import?session=$SESSION_ID" \
    -H "Content-Type: application/x-bibtex" \
    --data-binary "@$TMPBIB" 2>/dev/null)
  rm -f "$TMPBIB"

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  if [[ "$HTTP_CODE" == "201" ]]; then
    echo "  SUCCESS"; SUCCESS=$((SUCCESS + 1))
  else
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "  FAIL: HTTP $HTTP_CODE - $BODY"
    FAIL=$((FAIL + 1)); FAILED_ITEMS+=("$doi")
  fi

  sleep 0.5
done

echo ""
echo "=== Result ==="
echo "Success: $SUCCESS / ${#DOI_LIST[@]}"
echo "Failed:  $FAIL"

if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
  echo ""; echo "Failed DOIs:"
  for item in "${FAILED_ITEMS[@]}"; do echo "  - $item"; done
fi
