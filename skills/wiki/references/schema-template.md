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

- **source** (`wiki/sources/`) : note de lecture sur un document externe (paper, article, vidéo, livre). Une page = une source. Cite les claims clés avec citation directe quand utile. Porte le tracking d'ingestion : frontmatter `source_path`, `ingested` (boolean), `ingested_date`.
- **entity** (`wiki/entities/`) : personne, organisation, projet, lieu — toute chose nommée et identifiable.
- **concept** (`wiki/concepts/`) : idée, théorie, méthode, technique. La page synthétise ce que disent toutes les sources.
- **comparison** (`wiki/comparisons/`) : tableau comparatif de plusieurs entities/concepts.
- **synthesis** (`wiki/syntheses/`) : synthèse transverse issue d'un `/wiki query`, archivée pour réutilisation.

## Conventions

- **Langue : français exclusivement.** Tout le contenu (titres, headings, prose, bullets, frontmatter, MOC, index) est rédigé en français. Si une source est en anglais ou autre langue, elle est traduite / distillée en français avant ingestion. Citation entre guillemets dans la langue d'origine autorisée uniquement pour appuyer une définition technique précise ou une contradiction.
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
2. (Optionnel) Pré-création d'un stub `wiki/sources/<nom>.md` avec `ingested: false` pour planifier la lecture.
3. Analyse → distillation → `wiki/sources/<nom>.md` (frontmatter `source_path`, `ingested: true`, `ingested_date: YYYY-MM-DD`) + updates dans `wiki/concepts|entities/...`. Si un stub existait, on **complète** plutôt que de créer un doublon.
4. `index.md` mis à jour, MOC du dossier mis à jour, entrée loguée dans `log.md`.
5. `/wiki sources` permet de retrouver à tout moment les stubs `ingested: false` et les fichiers d'inbox jamais ingérés.
```
