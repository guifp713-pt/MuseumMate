# Data Model: Active Museum Entity Selection

No new Strapi content-type is introduced by this feature. This document covers
the one new configuration value and the one changed local cache shape.

## Active Museum Configuration (new)

A plain constant, not a database-backed entity — one instance per stack.

| Field | Type | Notes |
|---|---|---|
| `ACTIVE_ENTITY_DOCUMENT_ID` | string | The Strapi `documentId` of the `entidade` to serve. Default: `gqag59gr2pvu95qawb4dq1ol` (current fictional demo entity — see `research.md` §2). MUST be a non-empty value matching an existing `entidade` document under normal operation (clarified requirement). |

**Owning locations** (exactly one per stack — see `research.md` §1):
- Backend: `backend/app/src/config/museum.ts` (new file, single named export).
- Mobile: top of `TourAssistent-main/ApiHandler.js` (alongside the existing `baseUrl` constant).

**Lifecycle**: Changed only by an operator editing both owning locations to the
same value and rebuilding/reinstalling the app + redeploying the backend. Not
exposed to visitors, not stored per-device, not persisted in any database.

## Museum Entity (`entidade`) — unchanged

Existing content-type (`backend/app/src/api/entidade/content-types/entidade/schema.json`).
No schema changes. This feature only adds a `filters[documentId][$eq]=...`
constraint to the existing queries against it — see `contracts/active-entity-config.md`.

Confirmed via the local Strapi database: exactly one `entidade` document
exists today (documentId `gqag59gr2pvu95qawb4dq1ol`), localized into
pt/en/es/fr. A second, real-museum entity is being populated in parallel by
the user (Fase 2 of the overall rollout) and will have its own distinct
documentId once created.

## Local Content Cache (`cache` table, SQLite via `QtQuick.LocalStorage`) — changed

**Current schema**: `cache(lang TEXT, data TEXT)` — one row per language,
unconditionally overwritten on every successful fetch, with no notion of which
entity the cached `data` belongs to.

**New schema**: `cache(lang TEXT, documentId TEXT, data TEXT)`.

| Field | Type | Notes |
|---|---|---|
| `lang` | TEXT | Existing — one of `pt`/`en`/`es`/`fr`. |
| `documentId` | TEXT (new) | The `ACTIVE_ENTITY_DOCUMENT_ID` value in effect when this row was cached. |
| `data` | TEXT | Existing — JSON-serialized filtered entity payload. |

**Read**: `SELECT data FROM cache WHERE lang=? AND documentId=?` (both
parameters bound; previously only `lang=?`). A row cached under a
since-changed `documentId` (or a pre-migration row, `documentId IS NULL`) is
never returned — cache miss, falls through to a fresh network fetch. This is
the mechanism satisfying FR-005 (no explicit invalidation pass needed — see
`research.md` §5). The column is added to pre-existing installs via
`ALTER TABLE cache ADD COLUMN documentId TEXT` (try/caught, since it errors
once the column already exists) run right after the existing
`CREATE TABLE IF NOT EXISTS`.

**Write**: `DELETE FROM cache WHERE lang=?` (unchanged — still clears prior
rows for that language) followed by `INSERT INTO cache VALUES(?, ?, ?)`
including the current `documentId`.

## State: "No entity found" (new, mobile-side UI state only)

Not a persisted entity — a transient app state.

| Property | Type | Notes |
|---|---|---|
| `entityConfigError` (on `root` in `main.qml`) | bool | `true` when the filtered `/api/entidades` fetch succeeds (HTTP 200) but returns zero rows. Drives the new blocking full-screen error state, replacing the language-selection screen while `true`. Reset to `false` on the next successful `carregarDados` call that returns ≥1 entity. |
