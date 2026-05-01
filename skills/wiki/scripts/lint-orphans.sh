#!/usr/bin/env bash
# lint-orphans.sh — Détecte les pages clean sans backlink éditorial.
#
# Définition : une page est orpheline si aucune autre page clean (hors index.md,
# log.md, overview.md, _*-moc.md) ne la référence via [[wikilink]].
#
# Exit codes :
#   0 = aucune orpheline
#   2 = orphelines détectées
#   1 = erreur d'utilisation
#
# Usage :
#   lint-orphans.sh <vault> [--json]

set -eu

VAULT="${1:-}"
FORMAT="text"
if [ "${2:-}" = "--json" ]; then FORMAT="json"; fi

if [ -z "$VAULT" ] || [ ! -d "$VAULT/wiki" ]; then
  echo "Erreur : <vault> doit contenir un dossier wiki/" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Pages clean (cibles potentielles)
find "$VAULT/wiki" -type f -name "*.md" \
  ! -name "_*" \
  ! -name "index.md" \
  ! -name "log.md" \
  ! -name "overview.md" \
  > "$TMP/pages.txt"

# Noms (basename sans .md)
: > "$TMP/page-names.txt"
while IFS= read -r f; do
  basename "$f" .md >> "$TMP/page-names.txt"
done < "$TMP/pages.txt"

# Sources éditoriales (pages clean uniquement — exclut index, log, overview, MOC)
# C'est ce qui définit un "backlink éditorial".
find "$VAULT/wiki" -type f -name "*.md" \
  ! -name "_*" \
  ! -name "index.md" \
  ! -name "log.md" \
  ! -name "overview.md" \
  > "$TMP/editorial.txt"

# Extraction de tous les wikilinks référencés (alias et sections gérés)
: > "$TMP/refs.txt"
while IFS= read -r f; do
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
  ' "$f" >> "$TMP/refs.txt" || true
done < "$TMP/editorial.txt"

sort -u "$TMP/refs.txt" > "$TMP/refs-sorted.txt"
sort -u "$TMP/page-names.txt" > "$TMP/pages-sorted.txt"

# Orphelines = pages dans pages-sorted absentes de refs-sorted
comm -23 "$TMP/pages-sorted.txt" "$TMP/refs-sorted.txt" > "$TMP/orphans.txt"

ORPHAN_COUNT=$(wc -l < "$TMP/orphans.txt" | tr -d ' ')

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "orphans_count": %d,\n' "$ORPHAN_COUNT"
  printf '  "orphans": ['
  first=1
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    printf '\n    "%s"' "$name"
    first=0
  done < "$TMP/orphans.txt"
  if [ "$ORPHAN_COUNT" -gt 0 ]; then printf '\n  '; fi
  printf ']\n}\n'
else
  if [ "$ORPHAN_COUNT" -eq 0 ]; then
    echo "Aucune page orpheline."
  else
    echo "Pages orphelines (sans backlink éditorial) : $ORPHAN_COUNT"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      echo "  $name"
    done < "$TMP/orphans.txt"
  fi
fi

if [ "$ORPHAN_COUNT" -gt 0 ]; then
  exit 2
fi
exit 0
