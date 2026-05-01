# Format Obsidian Bases (`*.base`)

> **Quand lire ce fichier ?** Avant création ou modification d'une `.base`.

## Rôle

Les **Bases** sont les vues database d'Obsidian (plugin core depuis 2025). Elles transforment les pages en **lignes d'une table filtrable** sans bouger les fichiers — la base de données est virtuelle, calculée depuis le frontmatter et les propriétés du fichier.

Elles complètent les pages-synthèses :

- **Page synthèse** : narratif curaté, cite des sources.
- **Base** : vue tabulaire/filtrée, mise à jour automatique.

**Préférer une Base** dès qu'un besoin filtré ou tabulaire est récurrent.

## Structure YAML

```yaml
filters:
  and:
    - <expr>
    - <expr>
properties:
  <prop>:
    displayName: "<Label>"
views:
  - type: table | cards | list
    name: "<Nom de la vue>"
    filters: { ... }     # optionnel, AND avec filters globaux
    order: [...]         # ordre des colonnes
    sort:
      - { property: <prop>, direction: asc | desc }
```

## Filtres standards

Toujours inclure pour exclure les pages structurelles :

```yaml
filters:
  and:
    - file.inFolder("wiki")
    - file.ext == "md"
    - 'type != "moc"'
    - 'type != "index"'
    - 'type != "log"'
    - 'type != "schema"'
```

## Propriétés disponibles

| Propriété      | Source              |
|----------------|---------------------|
| `file.name`    | basename            |
| `file.path`    | chemin relatif      |
| `file.mtime`   | dernière modif      |
| `file.ctime`   | création            |
| `file.tags`    | tous tags du fichier|
| `<key>`        | depuis frontmatter  |

## 3 Bases par défaut (livrées avec le plugin)

| Base               | Vue                                            |
|--------------------|------------------------------------------------|
| `all-pages.base`   | Table : toutes les pages, triées par mtime    |
| `by-type.base`     | Multi-onglets : 1 vue par valeur de `type`     |
| `recent.base`      | Table : pages modifiées dans les 30 derniers jours |

Dans `${CLAUDE_PLUGIN_ROOT}/skills/wiki/templates/bases/`.

## Bases optionnelles

| Base               | Quand l'installer                             |
|--------------------|-----------------------------------------------|
| `by-status.base`   | Si convention `status/draft|reviewed|validated` est utilisée. Vue kanban par statut. |
| `by-techno.base`   | Si ≥5 pages tagguées `techno/*`. Vue par techno. |
| `<custom>.base`    | Tout besoin filtré récurrent (par auteur, par projet, etc.). |

`/wiki install-bases` détecte les conventions du vault et propose les bases pertinentes en plus des 3 par défaut.

## Adaptation contextuelle

À l'install, **ne pas copier brut** — adapter au profil du vault :

1. Lire `vault-profile.sh --json` pour connaître les types réels et les sous-dossiers.
2. Dans `by-type.base` : ne générer que les vues pour les types **présents** (si pas de `comparison`, retirer la vue Comparisons).
3. Si le vault utilise `wiki-content/` au lieu de `wiki/`, ajuster `file.inFolder()`.
4. Si tags hiérarchiques `techno/*` ≥ 5 occurrences → proposer `by-techno.base`.

## Quand créer une Base custom

- Besoin filtré récurrent (ex : "toutes les sources de 2024 sur l'IA").
- Vue tabulaire utile (ex : tracking de tâches via tag `tasks/*`).
- Kanban par statut.

**Ne PAS créer** une page synthèse pour ces besoins — elle deviendrait stale. Préférer une Base.

## Limites

- Les Bases ne peuvent pas faire d'agrégation (count, sum). Pour ça, préférer Dataview.
- Les filtres sur les tags hiérarchiques utilisent `file.tags.contains("techno/transformer")`.
