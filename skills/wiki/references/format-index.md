# Format `index.md`

> **Quand lire ce fichier ?** Avant toute modification de `wiki/index.md`.

## Rôle

`index.md` est le **catalogue agent** : la première chose qu'un LLM lit pour savoir ce que contient le wiki et où chercher. Il doit être exhaustif, factuel, et synchronisé avec le contenu réel des dossiers.

C'est complémentaire de :

- `overview.md` (narratif humain — big picture)
- `_<dir>-moc.md` (hubs Obsidian par dossier)
- `bases/*.base` (vues database)

## Structure

```markdown
# Index

Brève intro 1-2 phrases sur ce que contient le wiki.

## Sources

> Notes de lecture (1 page par source ingérée).

- [[paper-attention]] : Paper fondateur sur l'attention (2017).
- [[paper-bert]] : BERT, pré-training bidirectionnel (2018).

## Concepts

> Idées, théories, méthodes.

- [[transformer]] : Architecture neuronale auto-attentive.
- [[self-attention]] : Mécanisme cœur du transformer.

## Entities

> Personnes, organisations, projets, lieux.

- [[google-research]] : Équipe à l'origine du transformer.

## Comparisons

> Tableaux comparatifs (X vs Y).

- [[transformer-vs-rnn]] : Comparaison architecturale.

## Syntheses

> Synthèses transverses issues de `/wiki query`.

- [[evolution-attention-mechanisms]] : 2014-2024.
```

## Règles

1. **Une section H2 par sous-dossier** de `wiki/`. Ordre : suivre l'ordre du `_wiki_schema.md` (ou alphabétique par défaut).
2. **Intro 2-3 lignes en blockquote** sous chaque H2 — préserver l'existante si possible (l'humain peut l'avoir personnalisée).
3. **Liste alphabétique** des pages avec **résumé une ligne**.
4. Le résumé est extrait de :
   - le champ `description` du frontmatter si présent,
   - sinon la première phrase utile du corps de la page.
5. **Wikilinks par basename uniquement** — `[[transformer]]`, jamais `[[wiki/concepts/transformer]]`.
6. **Pas de chemin complet** : Obsidian résout par nom.
7. **Pas de doublons** : si une page change de dossier, retirer l'ancienne entrée.
8. **Pas de MOC ni de pages structurelles** dans l'index (`_*-moc.md`, `index.md`, `log.md`, `overview.md`, `_wiki_schema.md`).

## Synchronisation

Mettre à jour l'index après :

- création d'une page → ajouter une entrée
- renommage d'une page → mettre à jour le wikilink
- suppression d'une page → retirer l'entrée
- modification du `description` frontmatter → mettre à jour le résumé

`lint-index-desync.sh` détecte les désynchronisations. `/wiki refresh-index` régénère.

## Format minimal acceptable

Si l'index est très gros (>1000 pages), ne PAS dégrader le format. Garder résumé une-ligne et structure H2 par dossier — c'est ce qui le rend exploitable par un agent.
