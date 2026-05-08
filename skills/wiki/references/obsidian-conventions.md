# Conventions Obsidian

> **Quand lire ce fichier ?** Avant toute création ou modification d'une page du wiki.

## Langue

Tout le contenu rédigé est en **français exclusivement** : titres de page, headings, prose, bullets, descriptions frontmatter, entrées d'index, MOC, log. Une source en anglais (ou autre langue) est traduite / distillée en français avant ingestion. Citation entre guillemets dans la langue d'origine autorisée uniquement pour appuyer une contradiction ou une définition technique précise.

Les **filenames** restent en kebab-case ASCII (cf. section ci-dessous) — c'est une contrainte technique d'Obsidian, pas une langue.

## Wikilinks

Toujours utiliser la syntaxe `[[...]]`, **jamais** `[texte](chemin.md)` (sinon pas de graph view, pas de backlinks).

| Forme              | Usage                                  |
|--------------------|----------------------------------------|
| `[[page]]`         | Lien simple (résolu par nom de fichier)|
| `[[page\|texte]]`  | Lien avec alias visible                |
| `[[page#section]]` | Lien vers heading                      |
| `![[page]]`        | Embed (insère le contenu)              |
| `![[image.png]]`   | Image                                  |

Résolution : Obsidian cherche le **nom de fichier** (basename sans `.md`) **dans tout le vault**. D'où l'exigence d'unicité globale des filenames.

## Backlinks et graph view

- Tous les wikilinks alimentent automatiquement la graph view et le panneau backlinks.
- Inbox ↔ wiki et wiki ↔ wiki ; les deux sens comptent.
- Une page sans aucun backlink éditorial est **orpheline** (cf. `lint-orphans.sh`).

## Filenames

- **kebab-case**, max 60 caractères.
- **Uniques dans tout le vault** (sinon Obsidian ne sait pas où résoudre).
- ASCII préféré (les caractères accentués sont valides mais source de friction multi-OS).
- Pas d'espaces.

## Frontmatter (obligatoire)

```yaml
---
title: Titre lisible humain
type: source | entity | concept | comparison | synthesis
tags: [type/<type>, techno/<x>, status/<draft|reviewed|validated>]
date: YYYY-MM-DD
---
```

`title`, `type`, `tags`, `date` sont obligatoires. Champs optionnels : `description` (utilisé par index.md), `aliases`, `source` (URL ou path d'origine).

### Frontmatter spécifique aux pages `type: source`

Les pages dans `wiki/sources/` portent en plus trois champs qui suivent le cycle de vie d'ingestion du document :

```yaml
---
title: Attention Is All You Need
type: source
tags: [type/source, techno/transformer, status/reviewed]
date: 2026-04-30
source_path: inbox/2026-04-15-attention-is-all-you-need.pdf
ingested: true
ingested_date: 2026-04-30
---
```

| Champ           | Type    | Sens                                                                                          |
|-----------------|---------|-----------------------------------------------------------------------------------------------|
| `source_path`   | string  | Chemin (relatif au vault ou absolu) du document brut. Sert de clé d'identité anti-doublon.    |
| `ingested`      | boolean | `true` = document lu et distillé dans le wiki ; `false` = stub planifié, pas encore lu.        |
| `ingested_date` | string  | Date d'ingestion `YYYY-MM-DD`. Absent ou vide tant que `ingested: false`.                      |

Conventions :

- `/wiki ingest <path>` crée la page avec `ingested: true` et renseigne les trois champs.
- Un utilisateur peut **pré-créer** une page source en `ingested: false` (pile « à lire ») ; `/wiki ingest` la **complétera et basculera** `ingested: true` plutôt que d'en créer une nouvelle.
- L'identité d'une source est `source_path`, pas le filename de la page wiki — toujours grep `source_path:` avant de créer une page source.
- Tant que `ingested: false`, la page peut être minimale (frontmatter + 1 ligne) — pas de claim factuel à tracer.

## Callouts

```markdown
> [!info] Titre optionnel
> Contenu informatif.

> [!warning] Contradiction détectée
> Source A dit X, source B dit Y.

> [!question]
> Point ouvert à clarifier.

> [!tip]
> Astuce ou recommandation.
```

Types disponibles : `note`, `info`, `tip`, `success`, `question`, `warning`, `failure`, `danger`, `bug`, `example`, `quote`, `abstract`, `todo`.

## Tags hiérarchiques

Format `prefix/sub` : `techno/transformer`, `status/draft`, `type/source`. Permet le filtrage par préfixe dans le tag pane et les Bases.

## Headings

- Pas de `# Titre` dans le corps (le titre est dans le frontmatter).
- Le corps commence par `##`.
- Pas de HTML.

## Structure type d'une page

```markdown
---
title: Transformer
type: concept
tags: [type/concept, techno/transformer]
date: 2026-04-30
---
> [!info] Voir [[index]] pour l'index général.

## Définition

Le transformer est une architecture neuronale...

## Caractéristiques clés

- Self-attention
- Multi-head
- Feed-forward

## Sources

- [[paper-attention-is-all-you-need]]
- [[paper-bert]]

## Voir aussi

- [[self-attention]]
- [[positional-encoding]]
```

## Anti-patterns

- Markdown links `[texte](chemin)` au lieu de wikilinks.
- Filename avec espace ou MAJUSCULES.
- Frontmatter manquant ou incomplet.
- `# H1` dans le corps.
- HTML (`<br>`, `<div>`, etc.).
- Wikilinks vers le chemin complet (`[[wiki/concepts/transformer]]`) — utiliser uniquement le basename.
