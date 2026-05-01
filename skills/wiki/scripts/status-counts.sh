#!/usr/bin/env bash
# status-counts.sh — Compteurs et état du vault.
#
# Sortie :
#   - pages clean total
#   - notes inbox
#   - bases Obsidian
#   - dernière activité (mtime + page)
#   - détail par sous-dossier (count + présence MOC)
#
# Usage :
#   status-counts.sh <vault> [--json]

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

mtime_cmd() {
  if stat -f '%m' "$1" >/dev/null 2>&1; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

# Pages clean (hors structurels)
find "$VAULT/wiki" -type f -name "*.md" \
  ! -name "_*" \
  ! -name "index.md" \
  ! -name "log.md" \
  ! -name "overview.md" \
  > "$TMP/pages.txt"

PAGES_TOTAL=$(wc -l < "$TMP/pages.txt" | tr -d ' ')

# Inbox notes (hors assets)
INBOX_COUNT=0
if [ -d "$VAULT/inbox" ]; then
  INBOX_COUNT=$(find "$VAULT/inbox" -type f -name "*.md" ! -path "*/assets/*" | wc -l | tr -d ' ')
fi

# Bases
BASES_COUNT=0
if [ -d "$VAULT/wiki/bases" ]; then
  BASES_COUNT=$(find "$VAULT/wiki/bases" -type f -name "*.base" | wc -l | tr -d ' ')
fi

# Dernière activité (toute extension)
LAST_MTIME=0
LAST_FILE=""
if [ "$PAGES_TOTAL" -gt 0 ]; then
  while IFS= read -r f; do
    m=$(mtime_cmd "$f")
    if [ "$m" -gt "$LAST_MTIME" ]; then
      LAST_MTIME=$m
      LAST_FILE=$f
    fi
  done < "$TMP/pages.txt"
fi

# Détail par sous-dossier
find "$VAULT/wiki" -mindepth 1 -maxdepth 1 -type d \
  ! -name "bases" \
  > "$TMP/dirs.txt"

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "pages_total": %d,\n' "$PAGES_TOTAL"
  printf '  "inbox_notes": %d,\n' "$INBOX_COUNT"
  printf '  "bases": %d,\n' "$BASES_COUNT"
  if [ -n "$LAST_FILE" ]; then
    rel=${LAST_FILE#"$VAULT/"}
    printf '  "last_activity": { "mtime": %s, "path": "%s" },\n' "$LAST_MTIME" "$rel"
  else
    printf '  "last_activity": null,\n'
  fi
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
  printf '\n  }\n'
  printf '}\n'
else
  echo "=== Status : $VAULT ==="
  echo "Pages clean       : $PAGES_TOTAL"
  echo "Notes inbox       : $INBOX_COUNT"
  echo "Bases Obsidian    : $BASES_COUNT"
  if [ -n "$LAST_FILE" ]; then
    rel=${LAST_FILE#"$VAULT/"}
    echo "Dernière activité : $rel (mtime $LAST_MTIME)"
  else
    echo "Dernière activité : (aucune)"
  fi
  echo
  echo "Détail par sous-dossier :"
  while IFS= read -r d; do
    name=$(basename "$d")
    cnt=$(find "$d" -maxdepth 1 -type f -name "*.md" ! -name "_*" | wc -l | tr -d ' ')
    moc=""
    if ls "$d"/_*-moc.md >/dev/null 2>&1; then moc=" [MOC]"; fi
    echo "  $name : $cnt pages$moc"
  done < "$TMP/dirs.txt"
fi
