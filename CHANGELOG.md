# Changelog

## [Unreleased]
- Tracking d'ingestion des sources : nouvelles propriétés frontmatter `source_path`, `ingested` (booléen lu/non-lu), `ingested_date` sur les pages `wiki/sources/`.
- Le sous-agent `wiki-ingest` détecte par `source_path` les ingestions déjà faites (`already_ingested`) et les stubs à compléter (`complete_stub`) — plus de doublons silencieux quand le même document est ré-ingéré.
- Nouvelle commande `/wiki sources [--unread]` et script `list-unread-sources.sh` : inventaire des sources lues, stubs `ingested: false`, et fichiers d'`inbox/` sans page source.
- Base `by-type` étendue avec deux vues `Sources lues` / `Sources à lire` filtrées sur `ingested`.

## [1.0.0]
- Initial release
