# Conventions Obsidian

> **Quand lire ce fichier ?** Avant toute création ou modification d'une page du wiki.

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
