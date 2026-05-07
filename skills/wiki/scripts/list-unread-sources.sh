#!/usr/bin/env bash
# list-unread-sources.sh — Inventaire d'ingestion des sources.
#
# Trois sections :
#   - read     : pages wiki/sources/*.md avec frontmatter `ingested: true`
#   - stubs    : pages wiki/sources/*.md avec frontmatter `ingested: false`
#   - inbox    : fichiers d'inbox sans correspondance dans aucun `source_path:`
#
# Identité d'une source = champ `source_path` du frontmatter de la page.
#
# Exit codes :
#   0 = aucun stub, aucun fichier d'inbox non ingéré (vault clean côté ingestion)
#   2 = stubs ou fichiers d'inbox restants
#   1 = erreur d'utilisation
#
# Usage :
#   list-unread-sources.sh <vault> [--json|--unread]
#
# Flags :
#   --json    : sortie JSON
#   --unread  : sortie texte limitée aux stubs et fichiers d'inbox non ingérés

set -eu

VAULT="${1:-}"
FORMAT="text"
ONLY_UNREAD=0
case "${2:-}" in
  --json)   FORMAT="json" ;;
  --unread) ONLY_UNREAD=1 ;;
  "")       ;;
  *)
    echo "Erreur : flag inconnu '${2}'. Attendu : --json ou --unread." >&2
    exit 1
    ;;
esac

if [ -z "$VAULT" ] || [ ! -d "$VAULT/wiki" ]; then
  echo "Erreur : <vault> doit contenir un dossier wiki/" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

SOURCES_DIR="$VAULT/wiki/sources"
INBOX_DIR="$VAULT/inbox"

: > "$TMP/read.txt"
: > "$TMP/stubs.txt"
: > "$TMP/source-paths.txt"

# Parse pages sources : extraire ingested + source_path du frontmatter (entre les --- de tête).
parse_frontmatter() {
  awk '
    BEGIN { in_fm = 0; opened = 0 }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; opened = 1; next }
    in_fm && /^---[[:space:]]*$/   { in_fm = 0; exit }
    in_fm {
      if (match($0, /^[[:space:]]*ingested:[[:space:]]*/)) {
        v = substr($0, RSTART + RLENGTH)
        gsub(/[[:space:]"\047]/, "", v)
        print "ingested=" v
      }
      else if (match($0, /^[[:space:]]*source_path:[[:space:]]*/)) {
        v = substr($0, RSTART + RLENGTH)
        sub(/[[:space:]]+$/, "", v)
        gsub(/^["\047]|["\047]$/, "", v)
        print "source_path=" v
      }
    }
    END { if (!opened) print "no_frontmatter=1" }
  ' "$1"
}

if [ -d "$SOURCES_DIR" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    parsed=$(parse_frontmatter "$f")
    ingested=$(printf '%s\n' "$parsed" | sed -n 's/^ingested=//p' | head -n1)
    spath=$(printf '%s\n' "$parsed" | sed -n 's/^source_path=//p' | head -n1)
    rel=${f#"$VAULT/"}
    name=$(basename "$f" .md)
    line="$rel|$name|$spath"
    case "$ingested" in
      true|True|TRUE|yes|1)
        printf '%s\n' "$line" >> "$TMP/read.txt"
        ;;
      false|False|FALSE|no|0)
        printf '%s\n' "$line" >> "$TMP/stubs.txt"
        ;;
      *)
        # Pas de champ ingested : on considère stub par défaut (frontmatter incomplet à corriger).
        printf '%s\n' "$line" >> "$TMP/stubs.txt"
        ;;
    esac
    if [ -n "$spath" ]; then
      printf '%s\n' "$spath" >> "$TMP/source-paths.txt"
    fi
  done < <(find "$SOURCES_DIR" -type f -name "*.md" ! -name "_*")
fi

sort -u "$TMP/source-paths.txt" -o "$TMP/source-paths.txt"

# Fichiers d'inbox sans page source.
: > "$TMP/inbox-unmapped.txt"
if [ -d "$INBOX_DIR" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel=${f#"$VAULT/"}
    abs="$f"
    matched=0
    if [ -s "$TMP/source-paths.txt" ]; then
      while IFS= read -r sp; do
        [ -z "$sp" ] && continue
        if [ "$sp" = "$rel" ] || [ "$sp" = "$abs" ]; then
          matched=1
          break
        fi
      done < "$TMP/source-paths.txt"
    fi
    if [ "$matched" -eq 0 ]; then
      printf '%s\n' "$rel" >> "$TMP/inbox-unmapped.txt"
    fi
  done < <(find "$INBOX_DIR" -type f \
            ! -path "*/assets/*" \
            \( -name "*.md" -o -name "*.pdf" -o -name "*.txt" -o -name "*.html" \))
fi

READ_COUNT=$(wc -l < "$TMP/read.txt"           | tr -d ' ')
STUB_COUNT=$(wc -l < "$TMP/stubs.txt"          | tr -d ' ')
INBOX_UNMAPPED_COUNT=$(wc -l < "$TMP/inbox-unmapped.txt" | tr -d ' ')

emit_json_array() {
  local file="$1"; local kind="$2"
  printf '['
  local first=1
  while IFS='|' read -r path name spath; do
    [ -z "$path" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    if [ "$kind" = "page" ]; then
      printf '\n    { "page": "%s", "name": "%s", "source_path": "%s" }' "$path" "$name" "$spath"
    else
      printf '\n    "%s"' "$path"
    fi
    first=0
  done < "$file"
  if [ "$(wc -l < "$file" | tr -d ' ')" -gt 0 ]; then printf '\n  '; fi
  printf ']'
}

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "read_count": %d,\n'           "$READ_COUNT"
  printf '  "stubs_count": %d,\n'          "$STUB_COUNT"
  printf '  "inbox_unmapped_count": %d,\n' "$INBOX_UNMAPPED_COUNT"
  printf '  "read": '
  emit_json_array "$TMP/read.txt" page
  printf ',\n  "stubs": '
  emit_json_array "$TMP/stubs.txt" page
  printf ',\n  "inbox_unmapped": '
  emit_json_array "$TMP/inbox-unmapped.txt" path
  printf '\n}\n'
else
  if [ "$ONLY_UNREAD" -eq 0 ]; then
    echo "=== Sources lues (ingested: true) : $READ_COUNT ==="
    if [ "$READ_COUNT" -eq 0 ]; then
      echo "  (aucune)"
    else
      while IFS='|' read -r path name spath; do
        [ -z "$path" ] && continue
        if [ -n "$spath" ]; then
          echo "  $name  ←  $spath"
        else
          echo "  $name  (source_path manquant)"
        fi
      done < "$TMP/read.txt"
    fi
    echo
  fi

  echo "=== Stubs à lire (ingested: false) : $STUB_COUNT ==="
  if [ "$STUB_COUNT" -eq 0 ]; then
    echo "  (aucun)"
  else
    while IFS='|' read -r path name spath; do
      [ -z "$path" ] && continue
      if [ -n "$spath" ]; then
        echo "  $name  →  $spath"
      else
        echo "  $name  (source_path manquant)"
      fi
    done < "$TMP/stubs.txt"
  fi
  echo

  echo "=== Fichiers d'inbox sans page source : $INBOX_UNMAPPED_COUNT ==="
  if [ "$INBOX_UNMAPPED_COUNT" -eq 0 ]; then
    echo "  (aucun)"
  else
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      echo "  $path"
    done < "$TMP/inbox-unmapped.txt"
  fi
fi

if [ "$STUB_COUNT" -gt 0 ] || [ "$INBOX_UNMAPPED_COUNT" -gt 0 ]; then
  exit 2
fi
exit 0
