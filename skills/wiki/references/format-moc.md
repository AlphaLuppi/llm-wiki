# Format `_<dossier>-moc.md` (Map of Content)

> **Quand lire ce fichier ?** Avant création ou modification d'un MOC.

## Rôle

Un MOC (Map of Content) est un **hub** Obsidian pour un sous-dossier du wiki. Il sert :

- la **graph view** (cluster visuel par dossier),
- la **navigation utilisateur** (un clic vers toutes les pages du dossier).

Il **ne remplace pas** `index.md` (qui contient les résumés).

## Nommage

`_<dossier>-moc.md` :

- Préfixe `_` → remontée en tête du file explorer alphabétique.
- Suffixe `-moc` → unicité dans le vault (sinon collision si plusieurs dossiers ont une page « moc »).

Exemples : `_concepts-moc.md`, `_sources-moc.md`, `_entities-moc.md`.

## Création / suppression auto

| Pages clean dans le dossier | MOC                |
|-----------------------------|--------------------|
| < 3                         | **Pas** de MOC     |
| ≥ 3                         | MOC obligatoire    |

Si le dossier passe sous le seuil (suppressions), supprimer le MOC.

## Frontmatter

```yaml
---
title: <Dossier> MOC
type: moc
tags: [moc, <dossier>]
---
```

## Corps — variante <5 pages

```markdown
> [!info] Voir [[index]] pour les résumés.

## Toutes les pages

- [[page-a]]
- [[page-b]]
- [[page-c]]
```

## Corps — variante ≥5 pages

Sections par sous-thème **en plus** de la liste exhaustive :

```markdown
> [!info] Voir [[index]] pour les résumés.

## Architectures

- [[transformer]]
- [[mamba]]
- [[mixture-of-experts]]

## Mécanismes

- [[self-attention]]
- [[cross-attention]]
- [[positional-encoding]]

## Toutes les pages

- [[cross-attention]]
- [[mamba]]
- [[mixture-of-experts]]
- [[positional-encoding]]
- [[self-attention]]
- [[transformer]]
```

La section « Toutes les pages » est exhaustive et alphabétique. Les sous-thèmes sont curatoriaux — l'agent les compose à partir des tags hiérarchiques ou de la structure sémantique.

## Règles

1. **Pas de résumés** dans un MOC — juste des wikilinks. Les résumés vivent dans `index.md`.
2. **Wikilinks uniquement** (basenames).
3. **Toutes les pages clean du dossier** doivent apparaître dans la section « Toutes les pages ».
4. Les pages **structurelles** (`_*-moc.md`, `index.md`, `log.md`, `overview.md`) ne sont **jamais** dans un MOC.
5. Les sous-thèmes peuvent référencer une page plusieurs fois (transverse), mais la section exhaustive ne contient chaque page qu'une seule fois.

## Synchronisation

Après création / renommage / suppression d'une page : mettre à jour le MOC du dossier. `lint-moc-desync.sh` détecte les désynchronisations. `/wiki refresh-index` régénère tous les MOC.
