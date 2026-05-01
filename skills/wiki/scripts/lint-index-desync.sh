#!/usr/bin/env bash
# lint-index-desync.sh — Détecte la désync entre index.md et le contenu réel.
#
# Compare :
#   - pages clean sur disque vs entrées dans index.md
#   - entrées dans index.md vs pages réellement présentes
#
# Exit codes :
#   0 = synchronisé
#   2 = désync détectée
#   1 = erreur d'utilisation
#
# Usage :
#   lint-index-desync.sh <vault> [--json]

set -eu

VAULT="${1:-}"
FORMAT="text"
if [ "${2:-}" = "--json" ]; then FORMAT="json"; fi

if [ -z "$VAULT" ] || [ ! -d "$VAULT/wiki" ]; then
  echo "Erreur : <vault> doit contenir un dossier wiki/" >&2
  exit 1
fi

INDEX="$VAULT/wiki/index.md"
if [ ! -f "$INDEX" ]; then
  if [ "$FORMAT" = "json" ]; then
    printf '{ "vault": "%s", "error": "index.md absent" }\n' "$VAULT"
  else
    echo "Erreur : index.md absent (lance /wiki refresh-index)"
  fi
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Pages clean réelles
find "$VAULT/wiki" -type f -name "*.md" \
  ! -name "_*" \
  ! -name "index.md" \
  ! -name "log.md" \
  ! -name "overview.md" \
  -exec basename {} .md \; \
  | sort -u > "$TMP/disk.txt"

# Entrées dans index (tous les wikilinks)
awk '
  {
    s = $0
    while (match(s, /\[\[[^]]+\]\]/)) {
      link = substr(s, RSTART + 2, RLENGTH - 4)
      sub(/#.*/, "", link)
      sub(/\|.*/, "", link)
      sub(/^[[:space:]]+|[[:space:]]+$/, "", link)
      if (link != "") print link
      s = substr(s, RSTART + RLENGTH)
    }
  }
' "$INDEX" | sort -u > "$TMP/index.txt"

# Sur disque mais absentes de l'index
comm -23 "$TMP/disk.txt" "$TMP/index.txt" > "$TMP/missing-in-index.txt"
# Dans l'index mais absentes du disque
comm -13 "$TMP/disk.txt" "$TMP/index.txt" > "$TMP/extra-in-index.txt"

MISSING_COUNT=$(wc -l < "$TMP/missing-in-index.txt" | tr -d ' ')
EXTRA_COUNT=$(wc -l < "$TMP/extra-in-index.txt" | tr -d ' ')
TOTAL=$((MISSING_COUNT + EXTRA_COUNT))

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "missing_in_index_count": %d,\n' "$MISSING_COUNT"
  printf '  "extra_in_index_count": %d,\n' "$EXTRA_COUNT"

  printf '  "missing_in_index": ['
  first=1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    printf '\n    "%s"' "$p"
    first=0
  done < "$TMP/missing-in-index.txt"
  if [ "$MISSING_COUNT" -gt 0 ]; then printf '\n  '; fi
  printf '],\n'

  printf '  "extra_in_index": ['
  first=1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    printf '\n    "%s"' "$p"
    first=0
  done < "$TMP/extra-in-index.txt"
  if [ "$EXTRA_COUNT" -gt 0 ]; then printf '\n  '; fi
  printf ']\n}\n'
else
  if [ "$TOTAL" -eq 0 ]; then
    echo "Index synchronisé."
  else
    echo "Désync index.md : $TOTAL problèmes"
    if [ "$MISSING_COUNT" -gt 0 ]; then
      echo
      echo "Pages sur disque absentes de index.md ($MISSING_COUNT) :"
      while IFS= read -r p; do
        [ -z "$p" ] && continue
        echo "  $p"
      done < "$TMP/missing-in-index.txt"
    fi
    if [ "$EXTRA_COUNT" -gt 0 ]; then
      echo
      echo "Entrées dans index.md sans page sur disque ($EXTRA_COUNT) :"
      while IFS= read -r p; do
        [ -z "$p" ] && continue
        echo "  $p"
      done < "$TMP/extra-in-index.txt"
    fi
  fi
fi

if [ "$TOTAL" -gt 0 ]; then
  exit 2
fi
exit 0
