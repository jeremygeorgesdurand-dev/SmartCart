# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Jeremy and his household — people managing everyday grocery shopping, alone or together. Lists are frequently shared: one member creates a list, others join via a share code and see/edit it in real time. Non-technical end users testing on real devices (Samsung Galaxy Z Flip), French-speaking.

## Product Purpose

SmartCart is a French-language grocery list app: build a shopping list from a personal catalogue of articles, organize it by store aisle ("rayon") or home category, track estimated/confirmed prices per store, and check items off while shopping ("Mode Courses"). Success means grocery trips are faster to prepare for and cheaper to plan, and a shared list stays in sync for everyone shopping from it.

## Positioning

Three things a generic list app (Bring!, AnyList) doesn't combine:
1. **Price awareness** — prices are looked up automatically from community data (Open Food Facts / Open Prices) when the user hasn't entered one, with a graceful fallback to a similar-product average, so most items show at least an indicative price without manual entry.
2. **A reusable article catalogue** — articles are created once and reused across every list and every recipe-generated list (with duplicate detection), rather than re-typed per list.
3. **A fully native home-screen widget** — checking an item, adding an item, or opening a specific list from the widget never launches the Flutter app/Activity; it writes directly to the shared local database from native Android code.

## Operating Context

- Real-device testing on a physical Samsung Galaxy Z Flip (Android, One UI).
- Offline-first: a local SQLite database (sqflite) is authoritative; Firebase (Firestore + Auth) syncs across devices and powers collaborative lists (`listes_partagees`) when the user is signed in with Google. Account switch/sync is manual by design (no automatic merge of two accounts' data).
- Grocery-store aisle categories ("rayon") and home-storage categories ("catégorie") are both first-class, user-customizable groupings.
- Recipes can generate/complete a shopping list, auto-creating missing catalogue articles.

## Capabilities and Constraints

- Confirmed prices (per store) always take priority over the automatic indicative price; indicative prices are never persisted without explicit user action.
- Unit-aware pricing: a price is assumed per kg/L for weight/volume-measured ingredients and converted proportionally (e.g. 600 g of an 8 €/kg item ≈ 4.80 €).
- Collaboration is code-based (6-character share code), not account/contact-based; only the list owner can remove other members, and the owner can never be removed.
- The home-screen widget's "+" quick-add is a lightweight native Activity (translucent dialog), not the Flutter app — it must stay visually consistent with the app's own styling despite being built in Android views/XML rather than Flutter widgets.
- Optional features (Budget tab, Stats tab, showing prices at all) can be toggled off in settings.

## Brand Commitments

- Name: SmartCart. App is entirely in French (UI text, not just content) — this is a firm constraint, not a placeholder for future localization.
- Current brand color is a teal (~#006B5E), used across the app (Material theme seed) and hand-matched in the native widget/dialog drawables. Open to revisiting the palette/theme as part of design work — not a fixed constraint.

## Evidence on Hand

- Live, working app with real usage history this session (multiple rounds of real-device bug reports/fixes). No design mockups, marketing assets, or brand guideline docs exist beyond the current shipped UI itself.
- No user research, testimonials, or metrics beyond one primary tester's (Jeremy's) direct feedback — do not fabricate any.

## Product Principles

1. Never block on a missing price or a missing catalogue match — degrade gracefully (indicative price, auto-create article) rather than leaving a dead end.
2. Local state is the source of truth; cloud sync is best-effort and must never make the UI feel slower or data feel less safe.
3. Native platform conventions (Material 3, system Back, widget behavior) win over cross-platform uniformity — this is an Android app first.
4. Collaboration trust model is intentionally lightweight (code-based, small groups) but ownership boundaries (who can remove whom) must still be enforced, not just assumed.
5. Every fix ships to a real device in the same session — prefer concrete, testable improvements over speculative redesigns.

## Accessibility & Inclusion

No formal accessibility standard has been established yet; no specific user needs have been confirmed beyond general legibility (adjustable text-size scaling already exists in settings).
