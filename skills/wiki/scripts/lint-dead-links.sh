#!/usr/bin/env bash
# lint-dead-links.sh — Détecte les wikilinks pointant vers des pages absentes.
#
# Pour chaque [[X]] dans tout fichier markdown du vault, vérifie qu'une page
# X.md existe quelque part dans le vault. Gère [[X|alias]] et [[X#section]].
#
# Exit codes :
#   0 = aucun dead link
#   2 = dead links détectés
#   1 = erreur d'utilisation
#
# Usage :
#   lint-dead-links.sh <vault> [--json]

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

# Index de toutes les pages (basename .md, sans extension)
find "$VAULT" -type f -name "*.md" ! -path "*/.obsidian/*" \
  -exec basename {} .md \; \
  | sort -u > "$TMP/all-pages.txt"

# Liste des fichiers à scanner
find "$VAULT" -type f -name "*.md" ! -path "*/.obsidian/*" > "$TMP/files.txt"

# Extraction (link, fichier source)
: > "$TMP/refs.txt"
while IFS= read -r f; do
  awk -v src="$f" '
    {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        link = substr(s, RSTART + 2, RLENGTH - 4)
        sub(/#.*/, "", link)
        sub(/\|.*/, "", link)
        sub(/^[[:space:]]+|[[:space:]]+$/, "", link)
        if (link != "") print link "\t" src
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$f" >> "$TMP/refs.txt" || true
done < "$TMP/files.txt"

# Dead links
: > "$TMP/dead.txt"
while IFS=$'\t' read -r link src; do
  if ! grep -Fxq "$link" "$TMP/all-pages.txt"; then
    rel=${src#"$VAULT/"}
    echo "$link	$rel" >> "$TMP/dead.txt"
  fi
done < "$TMP/refs.txt"

sort -u "$TMP/dead.txt" -o "$TMP/dead.txt"
DEAD_COUNT=$(wc -l < "$TMP/dead.txt" | tr -d ' ')

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "dead_links_count": %d,\n' "$DEAD_COUNT"
  printf '  "dead_links": ['
  first=1
  while IFS=$'\t' read -r link src; do
    [ -z "$link" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    printf '\n    { "link": "%s", "source": "%s" }' "$link" "$src"
    first=0
  done < "$TMP/dead.txt"
  if [ "$DEAD_COUNT" -gt 0 ]; then printf '\n  '; fi
  printf ']\n}\n'
else
  if [ "$DEAD_COUNT" -eq 0 ]; then
    echo "Aucun dead link."
  else
    echo "Dead links détectés : $DEAD_COUNT"
    while IFS=$'\t' read -r link src; do
      [ -z "$link" ] && continue
      echo "  [[${link}]] dans $src"
    done < "$TMP/dead.txt"
  fi
fi

if [ "$DEAD_COUNT" -gt 0 ]; then
  exit 2
fi
exit 0
