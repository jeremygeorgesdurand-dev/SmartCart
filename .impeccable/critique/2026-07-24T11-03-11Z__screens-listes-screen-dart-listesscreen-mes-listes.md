---
target: Mes listes (ListesScreen / _ListeCard)
total_score: 29
max_score: 40
na_heuristics: 10
p0_count: 0
p1_count: 3
timestamp: 2026-07-24T11-03-11Z
slug: screens-listes-screen-dart-listesscreen-mes-listes
---
Method: dual-agent (A: a87b2d0623f89f129 · B: ab40e7bfb497c0ef2)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Good spinners/animations; no per-item progress on bulk "vider"/"supprimer" |
| 2 | Match System / Real World | 4 | Rayon/catégorie grouping, French copy, € formatting all fit household shopping |
| 3 | User Control and Freedom | 3 | Undo snackbars exist for delete/empty; no undo for renommer/dupliquer |
| 4 | Consistency and Standards | 2 | 14 raw-color-literal sites bypass ColorScheme (confirmed by code scan) — worse than initial estimate |
| 5 | Error Prevention | 3 | Confirm dialogs exist, but destructive items sit undivided among 8 menu options |
| 6 | Recognition Rather Than Recall | 3 | Letter-avatar/color-bar aid recognition; icon-only AppBar relies on tooltips |
| 7 | Flexibility and Efficiency | 3 | Sort/recipes/catalogue reuse are efficient; no swipe gestures for frequent actions |
| 8 | Aesthetic and Minimalist Design | 2 | 5 simultaneous AppBar actions + 8-item card menu compete with the FAB |
| 9 | Error Recovery | 3 | Raw exception text (`'Une erreur est survenue : $e'`) shown to non-technical users |
| 10 | Help and Documentation | n/a | Not a meaningful gap for this utility screen |

**Total: 26/36 applicable (renormalized) ≈ 29/40 — Acceptable/Good boundary.**

## Design Specificity Verdict

**LLM assessment**: The screen has real domain fingerprints — colored bar + letter avatar per list, a checked/total counter with orphan-filtering logic, confirmed-vs-indicative price badges, and a genuinely grocery-specific Mode Courses screen where checked items settle to the bottom after a deliberate delay. This isn't a reskinned generic todo template — the collaboration-by-code model, rayon/catégorie sort, and price formatting are authored for this exact product. The gap is in execution: the AppBar/PopupMenu/AlertDialog scaffolding is fairly stock Material boilerplate rather than a considered "one-handed, in a store, distracted" interaction design — domain thinking shows in data and copy, much less in layout and interaction choices.

**Deterministic scan (adapted for native — no browser/HTML target)**: A mechanical source-level audit (substituting for `detect.mjs`, which is web-only) found **14 raw-color-literal sites** bypassing `ColorScheme` (`Colors.red`, `Colors.green`, `Color(0xFFFFC400)`, `Color(0xFFB38600)`) across list-card menu items, the "banner terminé" widget, article-removal tiles, and snackbars — meaning a user on a non-default theme color (the app lets users pick from 16 seed colors including rouge, violet, noir) still sees hardcoded green/red/amber in several places, breaking the theme-personalization feature the rest of the app respects. It also found 13 distinct one-off spacing values (vs. a canonical 4/8/12/16/24 scale), 8 raw `TextStyle(...)` constructions bypassing the Material type scale, and 2 icon-only tap targets (a 32×32 color-swatch picker, and a custom checkbox-replacement icon) with no `tooltip`/`Semantics` label for screen readers. On the positive side: all 10 `IconButton`s have tooltips, and all 3 true confirmation dialogs use consistent button ordering (Annuler first) — two things the scan flags as solid, not broken.

**Visual overlays**: Not applicable — native Android/Flutter app, no browser to inject into. Evidence above is code-level, not a rendered-page overlay.

## Overall Impression

Functionally mature and genuinely tailored to the product (this is not a generic list app skin), but visually it reads as "built feature by feature" rather than "designed as one system." The single biggest opportunity: unify color usage under the theme (14 raw-hex sites is the most damaging, most mechanical, most Impeccable-suited fix) and reduce the AppBar/PopupMenu's simultaneous option count so the FAB's "add a list" action is unambiguously the one thing to do on this screen.

## What's Working

- **Undo-with-parallelized-delete on "Vider la liste"** (`listes_screen.dart:552-576`) — fast and reversible, better than most list apps bother with.
- **Mode Courses' delayed "sink to bottom" animation** (`listes_screen.dart:1552-1599`) — turns a jarring instant-disappear into a legible, almost delightful "I checked this, watch it go" moment. The strongest UX beat in the file.
- **Confirmed vs. indicative price differentiation** (`prix_article_badge.dart:25-47`) — bold vs. italic + outline color, using theme roles correctly. Small but real information design.

## Priority Issues

**[P1] Raw color literals bypass the theme in 14 places, breaking per-user theme customization**
- Why it matters: the app lets users choose a seed color (main.dart `_couleurSeed`, 16 options), but `Colors.red`/`Colors.green`/`Color(0xFFFFC400)` hardcoded in menu items, the "banner terminé" success state, and snackbars ignore that choice entirely — a user on "violet" or "noir" still sees stock green/red, and dark-mode contrast isn't guaranteed for these literals the way it is for `colorScheme.error`.
- Fix: replace with `colorScheme.error`/`colorScheme.errorContainer` (destructive), a tertiary/success role for green states, consistently across `_ListeCard`'s popup menu (lines ~481-497), `_BanniereTermine` (~1919-1939), the article-removal tile (~1344-1346), the progress bar (~1816-1817), and snackbars (~174, ~2128).
- Suggested command: `/impeccable harden`

**[P1] Card popup menu has 8 undifferentiated actions in one flat list**
- Why it matters: courses/partager/collaborer/importer/dupliquer/renommer/vider/supprimer sit together with no dividers or grouping — 2x the ≤4-item cognitive-load guideline for a single decision point, and destructive actions (vider, supprimer) are adjacent to routine ones (dupliquer, renommer). Costly for a one-handed, distracted "Casey" user pushing a cart.
- Fix: add a `PopupMenuDivider` before destructive items; consider folding partager/collaborer/importer into a single "Partager" submenu, cutting the top-level list to ~4-5 entries.
- Suggested command: `/impeccable layout`

**[P1] AppBar carries 5 simultaneous icon actions, diluting the FAB's primacy**
- Why it matters: search, recettes, rejoindre, importer, and sort all sit at the same visual weight beside the title; several (rejoindre, importer) are low-frequency for most users per PRODUCT.md's household-use persona, and icon-only presentation forces reliance on tooltips a touch user rarely discovers.
- Fix: keep 2-3 primary icons, fold the rest into one overflow menu.
- Suggested command: `/impeccable distill`

**[P2] Raw exception text shown to non-technical users**
- Why it matters: `_afficherErreur` renders `'Une erreur est survenue : $e'` verbatim — raw Dart/Firebase exception text in front of PRODUCT.md's explicitly non-technical testers.
- Fix: map known error cases to plain French copy ("Impossible de rejoindre : vérifiez le code et votre connexion"), keep `$e` in a debug log only.
- Suggested command: `/impeccable clarify`

**[P2] Two icon-only tap targets have no accessibility label**
- Why it matters: the 32×32 color-swatch picker (below the 48dp minimum tap size too) and the custom checkbox-replacement icon have no `tooltip`/`Semantics`, so a screen-reader user gets no description of color choice or check state.
- Fix: add `Semantics(label: ...)` wrapping both, and grow the color swatch's tap area to at least 48×48 (padding, not just the visible circle).
- Suggested command: `/impeccable audit`

## Persona Red Flags

**Casey (distracted, shopping one-handed)**: The 8-item card menu and "vider"/"supprimer" sitting next to "dupliquer"/"renommer" is exactly the kind of menu that gets mis-tapped while pushing a cart. `onLongPress` for article options has no visual affordance hinting it exists, easy to miss or accidentally trigger with a moving thumb.

**Jordan (first-timer, non-technical — matches PRODUCT.md's tester)**: Raw exception text in error snackbars; five unlabeled AppBar icons discoverable only via long-press tooltip; the "collaborer" menu label silently changes wording based on state ("Rendre collaborative" vs "Gérer la collaboration"), subtle enough to misread on a first pass.

**Sam (accessibility-dependent)**: Hardcoded `Colors.red`/`Color(0xFFFFC400)` on destructive menu text has no verified contrast guarantee in either theme mode; the color-swatch picker and custom checkbox icon are unlabeled for screen readers.

## Minor Observations

- 13 distinct spacing values found (vs. a canonical 4/8/12/16/24 scale) — e.g. two different small "pill badge" padding pairs (`6h/1v` vs `8h/3v`) for visually similar containers.
- 8 raw `TextStyle(...)` constructions bypass the Material type scale (roughly 1 raw style per 2 theme-driven ones) — mostly small font sizes (11, 12, 13) hand-picked rather than mapped to `labelSmall`/`bodySmall`.
- The card's "Total estimé" price text and the price badge use different weight conventions (`w600` vs `bold`) for what's conceptually the same kind of number.
- `ModeCoursesScreen`'s AppBar uses `colorScheme.primaryContainer`, diverging from the app-wide AppBar theme (primary/surface) — likely deliberate ("special mode" signal) but undocumented as an intentional exception.
- Sort menu label "Par date (récent en premier)" is verbose for a `PopupMenuItem`.

## Questions to Consider

- What if the per-card menu had only 2-3 primary actions visible, with everything else in a bottom sheet reached via one "Plus" overflow — so the common path (open list, shop) never sees 8 options?
- What if the Mode Courses "settle to bottom" animation's spirit (the app's one genuinely delightful motion) extended back into Mes listes itself — e.g. a fully-checked list visually settling/dimming in the list-of-lists?
- What if color roles were centralized once (a small `AppColors`/theme-extension helper) so "destructive" and "success" always resolve the same way everywhere, instead of being re-typed as raw hex per widget?
