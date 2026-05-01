#!/usr/bin/env bash
# vault-profile.sh — Profil sémantique d'un vault llm-wiki.
#
# Sortie :
#   - types frontmatter (avec compteurs)
#   - top 10 préfixes de tags hiérarchiques
#   - top 8 newest et oldest pages (par mtime)
#   - sous-dossiers réels de wiki/
#
# Usage :
#   vault-profile.sh <vault> [--json]

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

# Détection BSD vs GNU stat
mtime_cmd() {
  if stat -f '%m' "$1" >/dev/null 2>&1; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

# Liste des pages clean (hors structurels)
find "$VAULT/wiki" -type f -name "*.md" \
  ! -name "_*" \
  ! -name "index.md" \
  ! -name "log.md" \
  ! -name "overview.md" \
  ! -name "_wiki_schema.md" \
  > "$TMP/pages.txt"

# 1. Types frontmatter
: > "$TMP/types.txt"
while IFS= read -r f; do
  awk '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm && /^type:/ {
      sub(/^type:[[:space:]]*/, "")
      gsub(/["'\'']/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$f" >> "$TMP/types.txt" || true
done < "$TMP/pages.txt"

sort "$TMP/types.txt" | uniq -c | sort -rn > "$TMP/types-count.txt"

# 2. Préfixes de tags hiérarchiques (tag/sub → tag)
: > "$TMP/tags.txt"
while IFS= read -r f; do
  awk '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm && /^tags:/ {
      in_tags = 1
      sub(/^tags:[[:space:]]*/, "")
      if ($0 ~ /^\[/) {
        gsub(/[\[\]"'\'']/, "")
        n = split($0, arr, ",")
        for (i = 1; i <= n; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[i])
          if (arr[i] != "") print arr[i]
        }
        in_tags = 0
      }
      next
    }
    fm && in_tags && /^[[:space:]]*-/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/["'\'']/, "")
      gsub(/[[:space:]]+$/, "")
      if ($0 != "") print
      next
    }
    fm && in_tags && /^[^[:space:]]/ { in_tags = 0 }
  ' "$f" >> "$TMP/tags.txt" || true
done < "$TMP/pages.txt"

awk -F'/' '{ print $1 }' "$TMP/tags.txt" | sort | uniq -c | sort -rn | head -10 > "$TMP/tags-prefix.txt"

# 3. mtime sort
: > "$TMP/mtime.txt"
while IFS= read -r f; do
  m=$(mtime_cmd "$f")
  echo "$m	$f" >> "$TMP/mtime.txt"
done < "$TMP/pages.txt"

sort -rn "$TMP/mtime.txt" | head -8 > "$TMP/newest.txt"
sort -n  "$TMP/mtime.txt" | head -8 > "$TMP/oldest.txt"

# 4. Sous-dossiers réels de wiki/
find "$VAULT/wiki" -mindepth 1 -maxdepth 1 -type d \
  ! -name "bases" \
  > "$TMP/dirs.txt"

if [ "$FORMAT" = "json" ]; then
  # JSON output
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "page_count": %d,\n' "$(wc -l < "$TMP/pages.txt" | tr -d ' ')"

  # types
  printf '  "types": {\n'
  first=1
  while IFS= read -r line; do
    count=$(echo "$line" | awk '{ print $1 }')
    name=$(echo "$line" | awk '{ $1=""; sub(/^[[:space:]]+/, ""); print }')
    [ -z "$name" ] && continue
    if [ $first -eq 0 ]; then printf ',\n'; fi
    printf '    "%s": %d' "$name" "$count"
    first=0
  done < "$TMP/types-count.txt"
  printf '\n  },\n'

  # tag prefixes
  printf '  "tag_prefixes": {\n'
  first=1
  while IFS= read -r line; do
    count=$(echo "$line" | awk '{ print $1 }')
    name=$(echo "$line" | awk '{ $1=""; sub(/^[[:space:]]+/, ""); print }')
    [ -z "$name" ] && continue
    if [ $first -eq 0 ]; then printf ',\n'; fi
    printf '    "%s": %d' "$name" "$count"
    first=0
  done < "$TMP/tags-prefix.txt"
  printf '\n  },\n'

  # subdirs with counts
  printf '  "subdirs": {\n'
  first=1
  while IFS= read -r d; do
    name=$(basename "$d")
    cnt=$(find "$d" -maxdepth 1 -type f -name "*.md" ! -name "_*" | wc -l | tr -d ' ')
    moc="false"
    if ls "$d"/_*-moc.md >/dev/null 2>&1; then moc="true"; fi
    if [ $first -eq 0 ]; then printf ',\n'; fi
    printf '    "%s": { "pages": %d, "has_moc": %s }' "$name" "$cnt" "$moc"
    first=0
  done < "$TMP/dirs.txt"
  printf '\n  },\n'

  # newest
  printf '  "newest": [\n'
  first=1
  while IFS=$'\t' read -r m f; do
    rel=${f#"$VAULT/"}
    if [ $first -eq 0 ]; then printf ',\n'; fi
    printf '    { "path": "%s", "mtime": %s }' "$rel" "$m"
    first=0
  done < "$TMP/newest.txt"
  printf '\n  ],\n'

  # oldest
  printf '  "oldest": [\n'
  first=1
  while IFS=$'\t' read -r m f; do
    rel=${f#"$VAULT/"}
    if [ $first -eq 0 ]; then printf ',\n'; fi
    printf '    { "path": "%s", "mtime": %s }' "$rel" "$m"
    first=0
  done < "$TMP/oldest.txt"
  printf '\n  ]\n'

  printf '}\n'
else
  echo "=== Vault profile : $VAULT ==="
  echo "Pages clean : $(wc -l < "$TMP/pages.txt" | tr -d ' ')"
  echo
  echo "Types (frontmatter) :"
  if [ -s "$TMP/types-count.txt" ]; then
    while IFS= read -r line; do echo "  $line"; done < "$TMP/types-count.txt"
  else
    echo "  (aucun)"
  fi
  echo
  echo "Top préfixes de tags hiérarchiques :"
  if [ -s "$TMP/tags-prefix.txt" ]; then
    while IFS= read -r line; do echo "  $line"; done < "$TMP/tags-prefix.txt"
  else
    echo "  (aucun)"
  fi
  echo
  echo "Sous-dossiers de wiki/ :"
  while IFS= read -r d; do
    name=$(basename "$d")
    cnt=$(find "$d" -maxdepth 1 -type f -name "*.md" ! -name "_*" | wc -l | tr -d ' ')
    moc=""
    if ls "$d"/_*-moc.md >/dev/null 2>&1; then moc=" [MOC]"; fi
    echo "  $name ($cnt pages)$moc"
  done < "$TMP/dirs.txt"
  echo
  echo "8 plus récentes :"
  while IFS=$'\t' read -r m f; do
    rel=${f#"$VAULT/"}
    echo "  $rel"
  done < "$TMP/newest.txt"
  echo
  echo "8 plus anciennes :"
  while IFS=$'\t' read -r m f; do
    rel=${f#"$VAULT/"}
    echo "  $rel"
  done < "$TMP/oldest.txt"
fi
