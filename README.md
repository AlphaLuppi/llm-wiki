# llm-wiki

Plugin Claude Code qui crée et entretient un **wiki Obsidian-compatible** piloté par LLM. Ingestion de sources, requêtes, lint, maintenance automatique de l'index et des Maps of Content (MOC), capture continue.

> **Langue : français exclusivement.** Tout le contenu rédigé par le plugin (pages, MOC, index, schéma, log) l'est en français, quelle que soit la langue des sources ingérées. Voir la section « Langue » du `SKILL.md` pour les règles précises.

## Principe fondateur

Ce plugin implémente le pattern **« LLM Wiki »** décrit par Andrej Karpathy : <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>

L'idée : au lieu de faire du RAG classique (re-récupérer + re-générer à chaque requête), on **compile la connaissance une fois** dans un artefact markdown persistant et composable que le LLM maintient activement. L'humain fournit les sources ; le LLM se charge de toute la maintenance — synthèse, liaisons croisées, détection des contradictions, mise à jour de l'index.

Trois couches :

1. **Sources brutes** (immuables, hors vault ou dans `inbox/`)
2. **Wiki** (géré par l'IA — pages interconnectées, MOC, index, log)
3. **Schéma** (instructions du domaine — `_wiki_schema.md`)

Chaque source ingérée enrichit 10-15 pages existantes plutôt que de créer du contenu isolé. Les contradictions sont détectées et signalées explicitement. Le wiki est un **knowledge graph cumulatif**, pas un append-only.

## Installation

```bash
# Cloner localement
git clone <url-du-repo> /chemin/vers/llm-wiki

# Depuis Claude Code
/plugin install /chemin/vers/llm-wiki
```

## Composants

| Type      | Nom              | Rôle                                                                    |
|-----------|------------------|-------------------------------------------------------------------------|
| Skill     | `wiki`           | 9 commandes : `init`, `ingest`, `query`, `lint`, `status`, etc.         |
| Agent     | `wiki-ingest`    | Sous-agent read-only d'analyse de source (retourne plan d'écriture)     |
| Hook      | `SessionStart`   | Détecte un wiki dans `cwd`, suggère `/wiki brief`                        |
| Templates | `bases/*.base`   | 3 vues database par défaut (all-pages, by-type, recent)                  |
| Scripts   | `scripts/*.sh`   | Profil vault, status, lint orphans/dead-links/MOC/index (text + JSON)    |
| Refs      | `references/*.md`| Conventions chargées à la demande (Obsidian, format index/MOC/Bases)     |

## Architecture du wiki

```
<vault>/
├── .obsidian/                  # Config Obsidian (plugin core + community)
├── _wiki_schema.md             # Schéma de domaine (instructions LLM)
├── inbox/                      # Capture brute datée
│   └── assets/                 # Pièces jointes (images, PDFs, etc.)
└── wiki/                       # Knowledge base structurée
    ├── index.md                # Catalogue agent (H2 par dossier, résumés)
    ├── overview.md             # Narratif humain (big picture)
    ├── log.md                  # Journal d'opérations
    ├── bases/                  # Vues database Obsidian
    │   ├── all-pages.base
    │   ├── by-type.base
    │   └── recent.base
    ├── sources/                # Notes de lecture (1 page par source)
    │   └── _sources-moc.md     # MOC auto si ≥3 pages
    ├── entities/               # Personnes, orgs, projets, lieux
    ├── concepts/               # Idées, théories, méthodes
    ├── comparisons/            # Tableaux comparatifs (X vs Y)
    └── syntheses/              # Synthèses transverses (issues de /wiki query)
```

## 4 artefacts d'indexation (rôles non-recouvrants)

| Artefact            | Public cible      | Forme                              | Rôle                                       |
|---------------------|-------------------|------------------------------------|--------------------------------------------|
| `overview.md`       | Humain            | Narratif libre                     | Big picture, vision                        |
| `index.md`          | Agent / LLM       | H2 par dossier + résumés une-ligne | Catalogue exhaustif pour navigation rapide |
| `_<dir>-moc.md`     | Obsidian          | Wikilinks groupés par sous-thème   | Hubs pour la graph view (≥3 pages)         |
| `bases/*.base`      | Obsidian          | YAML (filtres + vues)              | Vues database (table, kanban, cards)       |

## Commandes (skill `wiki`)

| Commande                         | Description courte                                                            |
|----------------------------------|-------------------------------------------------------------------------------|
| `/wiki init`                     | Bootstrap vault Obsidian (`.obsidian/`, dossiers, schéma, bases)              |
| `/wiki ingest <path>`            | Ingère 1 ou N sources (délègue à `wiki-ingest`, écrit après validation)       |
| `/wiki query <question>`         | Synthétise une réponse depuis le wiki, propose archivage                      |
| `/wiki lint`                     | Détecte (read-only) orphelines, dead links, MOC/index désync, contradictions  |
| `/wiki status`                   | Compteurs (pages, inbox, bases, dernière activité, par dossier)               |
| `/wiki sources [--unread]`       | Inventaire d'ingestion : lues / stubs (`ingested: false`) / inbox sans page    |
| `/wiki update <page>`            | Relit toutes les sources liées et réécrit la page                             |
| `/wiki refresh-index`            | Régénère `index.md` + tous les MOC depuis le contenu réel                     |
| `/wiki install-bases`            | Installe / régénère les Bases avec adaptation au profil du vault              |
| `/wiki brief`                    | Briefing compact (≤30 lignes) pour cold-start agent                           |

## Tracking d'ingestion des sources

Chaque page `wiki/sources/<nom>.md` porte trois champs de frontmatter qui en suivent le cycle de vie :

```yaml
source_path: inbox/2026-04-15-attention.pdf
ingested: true            # ou false pour un stub planifié
ingested_date: 2026-04-30 # vide tant que ingested: false
```

`source_path` est la **clé d'identité anti-doublon** (et non le filename de la page wiki). Avant d'ingérer un document, le sous-agent grep `source_path:` dans `wiki/sources/` :

- aucune correspondance → création d'une nouvelle page source `ingested: true`,
- correspondance avec `ingested: false` → la page stub est **complétée** (corps rempli, frontmatter basculé `true` + `ingested_date`),
- correspondance avec `ingested: true` → on propose un update plutôt qu'une ré-ingestion.

L'utilisateur peut donc pré-créer un stub `ingested: false` pour planifier une lecture sans encore distiller le contenu. `/wiki sources` (et la base `by-type` mise à jour) listent à tout moment les stubs en attente et les fichiers d'`inbox/` jamais ingérés.

## Hook SessionStart

À l'ouverture d'une session, si `_wiki_schema.md` est trouvé dans le `cwd` (jusqu'à 3 niveaux), une ligne ~50 tokens est émise :

```
Wiki Obsidian détecté à <path> — tape /wiki brief pour explorer le catalogue.
```

Pas de brief auto pour ne pas polluer le contexte.

## Capture continue

Pendant une conversation, l'agent propose proactivement de noter les éléments pertinents dans le wiki — pas uniquement via `/wiki ingest`. Toute information durable mérite une page ou une mise à jour.

## Licence

MIT
