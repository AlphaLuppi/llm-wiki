#!/usr/bin/env bash
# lint-moc-desync.sh — Détecte la désync entre MOCs et contenu réel des dossiers.
#
# Pour chaque sous-dossier de wiki/ :
#   - si ≥3 pages clean mais pas de _<dossier>-moc.md → MOC manquant
#   - si <3 pages clean mais MOC existe → MOC superflu
#   - si MOC existe : pages listées dans MOC vs pages réelles → désync
#
# Exit codes :
#   0 = synchronisé
#   2 = désync détectée
#   1 = erreur d'utilisation
#
# Usage :
#   lint-moc-desync.sh <vault> [--json]

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

find "$VAULT/wiki" -mindepth 1 -maxdepth 1 -type d \
  ! -name "bases" \
  > "$TMP/dirs.txt"

: > "$TMP/issues.txt"

while IFS= read -r d; do
  name=$(basename "$d")
  # Pages réelles (basenames sans .md)
  : > "$TMP/dir-pages.txt"
  find "$d" -maxdepth 1 -type f -name "*.md" ! -name "_*" \
    -exec basename {} .md \; \
    | sort -u > "$TMP/dir-pages.txt"
  cnt=$(wc -l < "$TMP/dir-pages.txt" | tr -d ' ')

  # Trouver le MOC
  moc=""
  for candidate in "$d"/_*-moc.md; do
    if [ -f "$candidate" ]; then
      moc=$candidate
      break
    fi
  done

  if [ -z "$moc" ]; then
    if [ "$cnt" -ge 3 ]; then
      echo "missing	$name	-	$cnt pages, MOC absent" >> "$TMP/issues.txt"
    fi
    continue
  fi

  if [ "$cnt" -lt 3 ]; then
    rel=${moc#"$VAULT/"}
    echo "superfluous	$name	$rel	$cnt pages, MOC superflu" >> "$TMP/issues.txt"
    continue
  fi

  # Comparer wikilinks dans MOC vs pages réelles.
  # Exclure les liens méta (index/log/overview/MOC) qui sont conventions,
  # pas des références éditoriales.
  awk '
    {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        link = substr(s, RSTART + 2, RLENGTH - 4)
        sub(/#.*/, "", link)
        sub(/\|.*/, "", link)
        sub(/^[[:space:]]+|[[:space:]]+$/, "", link)
        if (link == "" || link == "index" || link == "log" || link == "overview") next_iter = 1
        else if (link ~ /-moc$/) next_iter = 1
        else next_iter = 0
        if (next_iter == 0) print link
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$moc" | sort -u > "$TMP/moc-links.txt"

  rel=${moc#"$VAULT/"}

  # Pages présentes dans dossier mais absentes du MOC
  while IFS= read -r p; do
    if ! grep -Fxq "$p" "$TMP/moc-links.txt"; then
      echo "missing-in-moc	$name	$rel	$p" >> "$TMP/issues.txt"
    fi
  done < "$TMP/dir-pages.txt"

  # Liens dans MOC mais pages absentes du dossier
  while IFS= read -r l; do
    if ! grep -Fxq "$l" "$TMP/dir-pages.txt"; then
      # Vérifier si la page existe ailleurs (sinon c'est un dead link, déjà couvert)
      if find "$VAULT" -type f -name "${l}.md" ! -path "*/.obsidian/*" | grep -q .; then
        echo "extra-in-moc	$name	$rel	$l" >> "$TMP/issues.txt"
      fi
    fi
  done < "$TMP/moc-links.txt"
done < "$TMP/dirs.txt"

ISSUE_COUNT=$(wc -l < "$TMP/issues.txt" | tr -d ' ')

if [ "$FORMAT" = "json" ]; then
  printf '{\n'
  printf '  "vault": "%s",\n' "$VAULT"
  printf '  "issues_count": %d,\n' "$ISSUE_COUNT"
  printf '  "issues": ['
  first=1
  while IFS=$'\t' read -r kind dir moc detail; do
    [ -z "$kind" ] && continue
    if [ $first -eq 0 ]; then printf ','; fi
    printf '\n    { "kind": "%s", "dir": "%s", "moc": "%s", "detail": "%s" }' \
      "$kind" "$dir" "$moc" "$detail"
    first=0
  done < "$TMP/issues.txt"
  if [ "$ISSUE_COUNT" -gt 0 ]; then printf '\n  '; fi
  printf ']\n}\n'
else
  if [ "$ISSUE_COUNT" -eq 0 ]; then
    echo "MOCs synchronisés."
  else
    echo "Désync MOC : $ISSUE_COUNT problèmes"
    while IFS=$'\t' read -r kind dir moc detail; do
      [ -z "$kind" ] && continue
      echo "  [$kind] $dir : $detail"
    done < "$TMP/issues.txt"
  fi
fi

if [ "$ISSUE_COUNT" -gt 0 ]; then
  exit 2
fi
exit 0
