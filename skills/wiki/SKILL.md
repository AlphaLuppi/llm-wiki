---
name: wiki
description: "Gère une base de connaissance Obsidian-compatible avec le pattern LLM Wiki (ingestion de sources, requêtes, lint, maintenance d'index). Usage : /wiki <commande> [args]"
argument-hint: "brief | init | ingest <path> | query <q> | lint | status | update <page> | refresh-index | install-bases"
---

# Skill `wiki`

Maintient un **wiki Obsidian-compatible** suivant le pattern « LLM Wiki » (Karpathy) : la connaissance est compilée une fois dans des pages markdown persistantes que le LLM enrichit cumulativement, plutôt que re-générée à chaque requête.

## Architecture du vault cible

```
<vault>/
├── .obsidian/                  # Config Obsidian
├── _wiki_schema.md             # Schéma de domaine
├── inbox/                      # Capture brute datée
│   └── assets/
└── wiki/
    ├── index.md                # Catalogue agent (H2 par dossier)
    ├── overview.md             # Narratif humain
    ├── log.md                  # Journal d'opérations
    ├── bases/*.base            # Vues database
    ├── sources/                # Notes de lecture
    ├── entities/               # Personnes, orgs, projets
    ├── concepts/               # Idées, théories, méthodes
    ├── comparisons/            # Tableaux comparatifs
    └── syntheses/              # Synthèses transverses
```

Les MOC (`_<dossier>-moc.md`) sont créés automatiquement dans chaque sous-dossier dès qu'il atteint **3 pages**, supprimés s'il repasse en dessous.

## Chargement à la demande

Le SKILL.md ne précharge **pas** les références. Charger selon la table :

| Action                                        | Fichier à lire                                                    |
|-----------------------------------------------|-------------------------------------------------------------------|
| Création / modif d'une page                   | `${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/obsidian-conventions.md` |
| Modif de `wiki/index.md`                      | `${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/format-index.md`    |
| Création / modif d'un MOC                     | `${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/format-moc.md`      |
| Création / modif d'une `*.base`               | `${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/format-bases.md`    |
| Pendant `/wiki init`                          | `${CLAUDE_PLUGIN_ROOT}/skills/wiki/references/schema-template.md` |

## Scripts disponibles

Tous dans `${CLAUDE_PLUGIN_ROOT}/skills/wiki/scripts/`, acceptent `<vault>` comme premier argument et `--json` comme second pour sortie machine.

| Script                  | Rôle                                                  |
|-------------------------|-------------------------------------------------------|
| `vault-profile.sh`      | Profil sémantique (types, tags, sous-dossiers, mtime) |
| `status-counts.sh`      | Compteurs (pages, inbox, bases, dernière activité)    |
| `lint-orphans.sh`       | Pages sans backlink éditorial                         |
| `lint-dead-links.sh`    | Wikilinks pointant vers pages inexistantes            |
| `lint-moc-desync.sh`    | MOC manquants / superflus / désync                    |
| `lint-index-desync.sh`  | Désync entre `index.md` et le contenu réel            |

Toujours préférer ces scripts à des find/grep ad hoc.

---

## Commande : `/wiki init`

**But.** Bootstrap un vault Obsidian-compatible.

**Étapes.**

1. Demander le chemin du vault (par défaut : `cwd`). Si déjà initialisé (`_wiki_schema.md` présent), confirmer avant d'écraser.
2. Si pas de `.obsidian/`, créer :

   ```
   .obsidian/app.json
   .obsidian/core-plugins.json
   .obsidian/community-plugins.json
   ```

   Contenu de `app.json` :
   ```json
   {
     "newLinkFormat": "shortest",
     "useMarkdownLinks": false,
     "attachmentFolderPath": "inbox/assets"
   }
   ```

   Contenu de `core-plugins.json` (activer ces plugins core) :
   ```json
   [
     "file-explorer", "global-search", "switcher", "graph", "backlink",
     "canvas", "outgoing-link", "tag-pane", "properties", "page-preview",
     "daily-notes", "templates", "note-composer", "command-palette",
     "editor-status", "bookmarks", "outline", "word-count", "file-recovery",
     "sync", "bases"
   ]
   ```

   Contenu de `community-plugins.json` :
   ```json
   [
     "table-editor-obsidian", "dataview", "obsidian-icon-folder",
     "obsidian-mind-map", "omnisearch", "obsidian-style-settings",
     "obsidian-tasks-plugin", "terminal"
   ]
   ```

   Informer l'utilisateur : **« Active ces community plugins dans Obsidian → Settings → Community plugins → Browse. L'agent ne peut pas les installer à ta place. »**

3. Créer l'arborescence :
   ```
   inbox/
   inbox/assets/
   wiki/sources/
   wiki/entities/
   wiki/concepts/
   wiki/comparisons/
   wiki/syntheses/
   wiki/bases/
   ```

4. Créer `_wiki_schema.md` depuis `references/schema-template.md`. Personnaliser **Domain** et **Tags Taxonomy** en fonction du contexte que l'utilisateur a fourni (ou en posant 1-2 questions ciblées s'il n'a rien dit).

5. Créer les fichiers structurels minimaux :
   - `wiki/index.md` : `# Index\n\nVide pour l'instant. Sera peuplé via /wiki ingest.\n`
   - `wiki/overview.md` : `# Overview\n\nVide pour l'instant.\n`
   - `wiki/log.md` : `# Log\n\n`

6. **Pas de MOC à l'init** (générés à ≥3 pages).

7. Installer les 3 bases par défaut depuis `${CLAUDE_PLUGIN_ROOT}/skills/wiki/templates/bases/` vers `wiki/bases/` (cp simple à l'init, l'adaptation arrive avec `/wiki install-bases`).

8. Loguer dans `log.md` : `- YYYY-MM-DD HH:MM — init : vault initialisé.`

---

## Commande : `/wiki ingest <path-or-glob>`

**But.** Ingérer 1 ou N sources documentaires en pages liées du wiki.

**Stratégie : déléguer par défaut au sous-agent `wiki-ingest`.**

Justification : le contenu intégral des sources peut être volumineux et stale rapidement. Le main thread reste léger en déléguant l'analyse à des sous-agents read-only qui retournent un **plan d'écriture structuré**. Le main thread valide avec l'utilisateur puis écrit.

### Spawn des sous-agents

| Nb de sources | Stratégie                                 |
|---------------|-------------------------------------------|
| 1-3           | 1 subagent par source, en parallèle       |
| 4+            | 3 subagents max, lots de ⌈N/3⌉ sources    |

**Plafond strict : 3 sous-agents simultanés.**

Spawn dans **un seul message** avec N appels `Agent` parallèles (`subagent_type=wiki-ingest`).

### Procédure complète

1. **Énumérer** les sources depuis le path/glob fourni.
2. **Partitionner** selon la stratégie ci-dessus.
3. **Spawn** des sous-agents en parallèle (un seul message). Chaque sous-agent reçoit :
   - le chemin du vault
   - les chemins des sources qu'il doit analyser
   - le contenu de `_wiki_schema.md` et `wiki/index.md`
4. **Collecter** les plans retournés (cf. format dans `agents/wiki-ingest.md`).
5. **Fusionner** les plans :
   - détecter les conflits inter-plans (ex : 2 plans veulent créer la même page),
   - dédupliquer les ajouts d'index,
   - consolider les changements de MOC,
   - aggréger les contradictions détectées.
6. **Présenter un récapitulatif** à l'utilisateur :
   - X sources analysées
   - Y pages à créer (lister)
   - Z pages à mettre à jour (lister avec sections impactées)
   - doublons sémantiques détectés
   - contradictions entre sources
   - **3-5 key insights** non triviaux
7. **Attendre validation** (par défaut : tout valider, ou page par page si l'utilisateur le demande).
8. **Écrire séquentiellement** après validation. **Charger** `references/obsidian-conventions.md` avant la première écriture.
9. Mettre à jour `index.md` (charger `references/format-index.md`).
10. Mettre à jour les MOC impactés (charger `references/format-moc.md` ; créer un MOC si un dossier passe à ≥3 pages).
11. Loguer **une seule entrée** dans `log.md` pour le batch : `- YYYY-MM-DD HH:MM — ingest : N sources, X créations, Y updates.`

### Override : ingest sans subagent

Si l'utilisateur demande explicitement (« ingest sans subagent », « inline ingest »), exécuter la procédure complète d'analyse + écriture dans le main thread, en suivant les mêmes étapes que `wiki-ingest` (voir `agents/wiki-ingest.md`).

---

## Commande : `/wiki query <question>`

**But.** Synthétiser une réponse depuis le wiki, avec citations.

**Étapes.**

1. Lire `wiki/index.md`.
2. Identifier les pages pertinentes pour la question (par mot-clé, par section H2, par tag).
3. Lire les pages identifiées (3-10 pages typique).
4. **Synthétiser** la réponse avec **citations en `[[wikilinks]]`** vers les pages utilisées. Toute affirmation factuelle doit pointer vers au moins une page source.
5. À la fin de la réponse, proposer :
   - **Archiver** comme `wiki/syntheses/<nom>.md` si la synthèse est réutilisable, ou
   - **Archiver** comme `wiki/comparisons/<nom>.md` si la question portait sur un X vs Y.

Si l'utilisateur accepte l'archivage : créer la page (charger `references/obsidian-conventions.md`), mettre à jour `index.md`, mettre à jour le MOC du dossier, loguer.

---

## Commande : `/wiki lint`

**STRICTEMENT READ-ONLY. Détecte, ne corrige pas.**

**Étapes.**

0. **Profiler** le vault : `vault-profile.sh "$VAULT" --json`. Vérifier la présence de `wiki/bases/*.base` (au moins les 3 par défaut).

1. **Détection mécanique** (parser les sorties JSON, ne pas exécuter avec output texte uniquement) :
   - `lint-orphans.sh "$VAULT" --json`
   - `lint-dead-links.sh "$VAULT" --json`
   - `lint-moc-desync.sh "$VAULT" --json`
   - `lint-index-desync.sh "$VAULT" --json`

2. **Analyse sémantique manuelle** (pas scriptable) :
   - **Contradictions** : pages avec `> [!warning]` ouverts, claims opposés sur le même sujet.
   - **Stale content** : pages avec `date` très ancienne par rapport au domaine.
   - **Gaps** : sujets fréquemment mentionnés (3+ pages) sans page dédiée.
   - **Doublons sémantiques** : 2 pages ≈ même sujet sous noms différents (ex : `transformer-architecture` et `transformer-model`).

3. **Aggréger** les findings et **proposer la commande dédiée** correspondante :
   - désync index → `/wiki refresh-index`
   - bases manquantes ou non adaptées → `/wiki install-bases`
   - corrections page par page → édition manuelle (lister les pages)

4. **Validation page par page** de l'utilisateur avant toute correction. Le lint **ne corrige rien** lui-même.

5. **Interdictions strictes pendant le lint** :
   - pas d'install bases,
   - pas de création de MOC,
   - pas de modif d'index.

6. **Loguer** : une entrée pour la détection (`- YYYY-MM-DD HH:MM — lint : N orphelines, M dead links, P désync MOC.`). Les éventuelles corrections font l'objet **d'une entrée séparée** par commande dédiée.

---

## Commande : `/wiki refresh-index`

**But.** Régénérer `index.md` et tous les MOC depuis le contenu réel des dossiers.

**Étapes.**

1. **Charger** `references/format-index.md` et `references/format-moc.md`.

2. Scanner `wiki/**/*.md` (hors structurels : `_*`, `index.md`, `log.md`, `overview.md`, `_wiki_schema.md`).

3. Pour chaque sous-dossier de `wiki/` :
   - Compter les pages clean.
   - Si ≥3 pages : préparer un MOC (créer ou mettre à jour `_<dossier>-moc.md`).
   - Si <3 pages : préparer la suppression du MOC s'il existe.

4. **Régénérer `index.md`** :
   - Une H2 par sous-dossier (ordre du `_wiki_schema.md`, sinon alphabétique).
   - Intro 2-3 lignes en blockquote — **préserver l'existante** quand possible (parser l'index actuel).
   - Liste alphabétique des pages, chacune avec **résumé une ligne** :
     - Extrait `description` du frontmatter si présent,
     - sinon première phrase utile du corps.

5. **Présenter le diff** avant écriture (ce qui change dans index, MOC créés, MOC supprimés, MOC mis à jour).

6. Après validation : écrire, puis **loguer** : `- YYYY-MM-DD HH:MM — refresh-index : index régénéré, K MOC mis à jour.`

---

## Commande : `/wiki install-bases [--include status] [--all] [--force] [--no-adapt]`

**But.** Installer ou régénérer les Bases avec **adaptation au profil du vault**.

**Pas un simple `cp`.**

**Étapes.**

1. **Charger** `references/format-bases.md`.

2. `vault-profile.sh "$VAULT" --json` pour détecter :
   - sous-dossiers réels,
   - types frontmatter réellement utilisés,
   - tags hiérarchiques (préfixes ≥5 occurrences).

3. **Adapter chaque template** :
   - **`by-type.base`** : ne générer que les vues correspondant aux types **réellement utilisés**. Si le vault n'a pas de `comparison`, retirer la vue Comparisons.
   - **`all-pages.base`** : ajuster `file.inFolder("wiki")` si le dossier de contenu n'est pas `wiki/`.
   - **`recent.base`** : pas d'adaptation nécessaire.

4. **Proposer des bases supplémentaires** détectées :
   - tags `techno/*` ≥5 pages → proposer `by-techno.base`
   - tags `status/*` (avec `--include status` ou si la convention est utilisée) → proposer `by-status.base` (kanban)
   - sous-dossier custom ≥5 pages → proposer une base focalisée
   - `--all` : proposer toutes les bases optionnelles

5. **Présenter** la liste des bases qui seront installées (avec adaptations).

6. **Validation par base** (ou tout en bloc).

7. **Ne pas écraser** les bases existantes sauf `--force`.

8. **`--no-adapt`** : copier brut depuis les templates (debug / fallback).

9. **Loguer** : `- YYYY-MM-DD HH:MM — install-bases : N bases installées (M adaptées au profil).`

---

## Commande : `/wiki brief`

**But.** Briefing compact (≤30-40 lignes) pour qu'un agent en cold-start sache ce que contient le wiki.

**Étapes.**

1. **Lire 3 fichiers seulement** : `_wiki_schema.md`, `wiki/index.md`, `wiki/overview.md`.
2. **NE PAS** lire les pages individuelles.
3. **NE PAS** loguer (read-only).
4. Produire un briefing au format :

```
Wiki : <vault>
Domaine : <1 phrase depuis _wiki_schema.md>

Stats : X pages, Y dossiers, Z bases, dernière activité <date>.

— sources/ (N pages) : <intro 1 ligne>
  Pages clés : [[page1]] [[page2]] [[page3]] [[page4]] [[page5]]

— concepts/ (N pages) : <intro 1 ligne>
  Pages clés : [[page1]] ...

(...)

MOC disponibles : [[_sources-moc]] [[_concepts-moc]] (...)

Pour aller plus loin :
- /wiki query <question> : synthèse avec citations
- /wiki status : compteurs
- /wiki lint : audit (read-only)
- wiki/overview.md : narratif humain
```

5. **3-5 pages représentatives par dossier** (nouveauté + connexité dans la graph). Ne PAS lister tout l'index.

---

## Commande : `/wiki status`

**But.** Wrapper sur `status-counts.sh`.

**Étapes.**

1. Exécuter `status-counts.sh "$VAULT"`.
2. Afficher la sortie texte directement.
3. Pas de log.

---

## Commande : `/wiki update <page>`

**But.** Relire toutes les sources liées à une page et la réécrire avec la synthèse à jour.

**Étapes.**

1. **Charger** `references/obsidian-conventions.md`.
2. Localiser la page dans le vault. Si plusieurs candidats : demander.
3. Lire la page courante (frontmatter + corps).
4. Identifier toutes les sources liées (wikilinks vers pages dans `sources/`, ou backlinks depuis `sources/`).
5. Relire ces sources.
6. **Re-synthétiser** le corps en intégrant tout ce qui a été appris depuis (nouvelles sources, contradictions résolues, claims précisés).
7. **Présenter le diff** avant écriture.
8. Écrire après validation, mettre à jour `index.md` si le `description` change, mettre à jour le MOC si le titre change.
9. Loguer : `- YYYY-MM-DD HH:MM — update : <page>.`

---

# Règles de comportement (lire à chaque démarrage de commande d'écriture)

## Avant toute opération d'écriture

- Lire `_wiki_schema.md` ET `wiki/index.md`.
- Vérifier la convention de langue de l'utilisateur (s'aligner sur l'existant — si le vault est en français, écrire en français ; si en anglais, écrire en anglais).

## Anti-doublon (avant création de page)

- `grep` dans `wiki/index.md` sur le nom proposé **ET ses synonymes**.
- Si match approximatif → **proposer un update** plutôt qu'une création.

## Lien et indexation

- Toujours mettre à jour `index.md` après création / renommage / suppression de page.
- Toujours mettre à jour le MOC du dossier après création / renommage / suppression.
- **Créer le MOC** si le dossier passe à ≥3 pages, **le supprimer** s'il repasse en dessous.
- Toujours ajouter une entrée dans `log.md` après toute opération d'écriture.

## Préférences structurelles

- **Préférer un update** plutôt qu'une création de page.
- **Préférer une Base** plutôt qu'une page synthèse pour les vues filtrées / tabulaires / récurrentes.
- Préférer les **scripts pré-écrits** dans `${CLAUDE_PLUGIN_ROOT}/skills/wiki/scripts/` plutôt que des find/grep ad hoc.

## Sources et contradictions

- **Ne jamais modifier** les sources externes au vault (immuables).
- Toute affirmation factuelle dans une page wiki **trace vers une source** via `[[wikilink]]`.
- Détecter et signaler les **contradictions** avec `> [!warning]`.

## Séparation détection / action

- `/wiki lint` **détecte**, ne corrige **pas**.
- Les corrections passent par les commandes dédiées (`/wiki refresh-index`, `/wiki install-bases`, ou édition manuelle).
- Loguer **détection** et **corrections** dans des entrées séparées.

## Validation utilisateur

- **Pas d'écriture silencieuse**. Présenter un diff ou un récap avant toute écriture.
- Sauf `init` (création initiale acceptée comme implicite après confirmation du chemin).

## Capture continue

Pendant les conversations (en dehors d'une commande explicite), **proposer proactivement** de noter dans le wiki tout élément durable qui apparaît :

- une décision technique justifiée,
- un fait nouveau sur une entité connue,
- un concept utilisé pour la première fois,
- une comparaison qui clarifie un choix.

Format de la proposition : « *Ce point me semble durable — veux-tu que je l'ingère dans `wiki/concepts/<nom>.md` ?* »

Ne PAS attendre que l'utilisateur lance `/wiki ingest`.

## Double-check avant écriture

Avant d'écrire toute page :

1. **Anti-doublon** : `grep` dans `index.md` (et synonymes).
2. **Contradictions** : si la nouvelle info contredit une page existante, ouvrir un `> [!warning]`.
3. **Impacts croisés** : quelles pages mentionnent ce sujet ? Faut-il les mettre à jour ?
4. **Alignement factuel** : la nouvelle info utilise-t-elle la même terminologie que le reste du wiki ?
5. **Cohérence index/MOC** : l'index et le MOC du dossier reflètent-ils bien le nouvel état ?
