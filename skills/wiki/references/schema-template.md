# Template `_wiki_schema.md`

> **Quand lire ce fichier ?** Pendant `/wiki init`, pour générer le schéma initial du vault.

Ce qui suit est le contenu littéral à écrire dans `<vault>/_wiki_schema.md` au moment du bootstrap. Personnaliser **Domain** et **Tags Taxonomy** selon le contexte fourni par l'utilisateur.

```markdown
# Wiki Schema

> Instructions de domaine pour ce wiki. Lu en premier par tout agent qui ingère, requête ou maintient le vault.

## Domain

<!-- Une phrase décrivant le domaine couvert par ce wiki.
     Exemples :
     - "Recherche en deep learning et NLP."
     - "Veille produit sur les outils de productivité."
     - "Notes de lecture sur la philosophie politique."
     À remplir par l'utilisateur. -->

## Page Types

- **source** (`wiki/sources/`) : note de lecture sur un document externe (paper, article, vidéo, livre). Une page = une source. Cite les claims clés avec citation directe quand utile.
- **entity** (`wiki/entities/`) : personne, organisation, projet, lieu — toute chose nommée et identifiable.
- **concept** (`wiki/concepts/`) : idée, théorie, méthode, technique. La page synthétise ce que disent toutes les sources.
- **comparison** (`wiki/comparisons/`) : tableau comparatif de plusieurs entities/concepts.
- **synthesis** (`wiki/syntheses/`) : synthèse transverse issue d'un `/wiki query`, archivée pour réutilisation.

## Conventions

- **Une page par entité/concept**, pas de doublons. Avant création, grep `wiki/index.md` sur le nom proposé ET ses synonymes.
- Toute affirmation factuelle **trace vers une source** via `[[wikilink]]`.
- Les **contradictions** entre sources sont signalées explicitement avec `> [!warning]` et résolues dans la page (qui dit quoi, qui semble plus fiable).
- **Bullets > prose** pour les faits. Prose pour les transitions et le raisonnement.
- Maintenir `wiki/overview.md` à jour quand la big picture change.
- Les pages structurelles (`index.md`, `log.md`, `overview.md`, `_*-moc.md`) ne reçoivent pas de contenu éditorial — elles sont régénérables.

## Tags Taxonomy

<!-- Adapter à votre domaine. Exemples génériques : -->

- `status/draft` | `status/reviewed` | `status/validated`
- `type/source` | `type/entity` | `type/concept` | `type/comparison` | `type/synthesis`
- `techno/<x>` (si pertinent au domaine)
- `topic/<x>` (taxonomie thématique large)

## Workflow d'ingestion

1. Source brute → `inbox/YYYY-MM-DD-<nom>.md` (immuable).
2. Analyse → distillation → `wiki/sources/<nom>.md` + updates dans `wiki/concepts|entities/...`.
3. `index.md` mis à jour, MOC du dossier mis à jour, entrée loguée dans `log.md`.
```
