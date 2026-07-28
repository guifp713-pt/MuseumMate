# Research: Active Museum Entity Selection

## 1. Where does the active-entity identifier live, given two separate runtimes?

**Decision**: One owning constant per stack — `ACTIVE_ENTITY_DOCUMENT_ID` exported
from `backend/app/src/config/museum.ts` (backend) and declared at the top of
`ApiHandler.js` (mobile) — kept equal by operator discipline when switching
museums, not by a shared runtime file.

**Rationale**: The mobile app (compiled Qt/QML, runs on visitor devices) and the
Strapi backend (Node.js server) are physically separate deployables built and
shipped independently; there is no single file either could read from at
runtime without introducing a new dependency (e.g., the app fetching its
"active entity" from the backend at startup, or the backend reading from a
file the app's build produces). Both alternatives were rejected (see below) as
disproportionate for a value that already changes rarely and deliberately
(build/deploy-time, per the spec's own Assumptions and NFR "reversible in
seconds via rebuild"). The constitution's Environment Configuration Discipline
principle is about *not duplicating a value across multiple files within the
same stack* (the exact `ApiHandler.js`/`AnalyticsHandler.js` `baseUrl` problem
it calls out) — it does not require a single physical file spanning two
different runtimes. Keeping exactly one owning file per stack already prevents
the same failure mode from recurring within either stack.

**Alternatives considered**:
- *Backend exposes the active documentId via an API, mobile app fetches it at
  startup*: rejected — adds a new runtime dependency and failure mode (what if
  that call fails before the app knows which entity to request?) for a value
  that only needs to change at deploy time, not at runtime. Violates
  Simplicity/YAGNI for no present need.
- *Single shared JSON/env file committed to the repo, read by both stacks'
  build tooling*: rejected as unnecessary machinery for a two-stack monorepo
  with no shared build step today; would require wiring a new step into the
  qmake/Android build *and* the Strapi build. Revisit only if a third
  consumer of the same value appears.
- *Two independently hardcoded values, each stack owning its own, no shared
  naming/documentation convention*: rejected — this is the status quo
  `baseUrl` mistake the constitution explicitly calls out; instead both
  constants are named identically (`ACTIVE_ENTITY_DOCUMENT_ID`) and each is
  the single such constant in its stack, minimizing the chance of silent
  drift.

## 2. What is the current default value, and does one already exist?

**Decision**: Default both stacks' constant to `gqag59gr2pvu95qawb4dq1ol` — the
documentId of the existing "Northern Textile Industry" / "Indústria Têxtil do
Norte" fictional demo entity, confirmed as the only `entidade` row currently in
the local Strapi database (all four locale variants — pt/en/es/fr — share this
same documentId, as expected for one Strapi 5 "document" with localizations).

**Rationale**: This directly satisfies the clarified requirement that the
configured identifier must always default to a known-valid entity. Since only
one entity exists today, defaulting to it is both correct and the only
possible non-empty choice; once a second (real) entity finishes being
populated (in progress in parallel, per the user), switching both constants to
its documentId is the exact scenario this feature exists to support.

**Alternatives considered**: Leaving the constant unset/blank by default was
rejected outright — it would trivially trigger the "not found" error path on
first run, which the clarified requirement explicitly rules out as the normal
state.

## 3. How to filter server-side on both existing Strapi query call-sites?

**Decision**:
- Mobile (`ApiHandler.js`, `getData`): append
  `&filters[documentId][$eq]=<ACTIVE_ENTITY_DOCUMENT_ID>` to the existing
  `/api/entidades` REST URL, alongside the existing `locale=` and `populate[...]`
  params.
- Backend (`assistant-catalog.ts`, `getCatalog`): add
  `filters: { documentId: { $eq: ACTIVE_ENTITY_DOCUMENT_ID } }` to both
  `strapi.documents('api::entidade.entidade').findMany({...})` calls (base-locale
  fetch and localized-overlay fetch).

**Rationale**: Both call sites already use Strapi's native REST/Document Service
query mechanisms (`filters[...]` query params for the REST API; a `filters`
object for `strapi.documents().findMany()`), so filtering happens inside
Strapi's own query execution (server-side, as the spec/NFR requires) with no
new client-side post-filtering logic. This is a one-line addition at each of
the two call sites — no new abstraction needed.

**Alternatives considered**: Fetching all entities and filtering the returned
array in JS/TS (client-side) was rejected — this is exactly the "wastes payload
transferring data you won't show" problem the source material (`NFR-1.3`)
calls out, and it does not shrink the assistant's prompt payload for
`assistant-catalog.ts`, which matters more as a second real entity's content is
added in parallel.

## 4. How does the mobile app detect and surface "0 entities returned"?

**Decision**: `ApiHandler.js`'s `getData` callback now passes back whatever the
filtered API returned (0 or 1 entities); `main.qml`'s `carregarDados` checks
`dados.length === 0` after a successful (HTTP 200) response and, if so, sets a
new `entityConfigError` property to `true` instead of building `novoModelo` from
an empty result. A new blocking full-screen error `Rectangle` (declared
alongside the existing language-selection `Column`, shown when
`entityConfigError` is true and taking priority over it) replaces the
language-selection screen in that state — matching the clarified requirement
that misconfiguration must show a clear, blocking error rather than empty
screens.

**Rationale**: This reuses the exact data flow already in place (`getData` →
`carregarDados` → `appData`) with the smallest possible addition: one length
check and one new UI state. It requires no change to `getEntities`/`getMaps`/
etc., since with the new filter in place they will only ever receive 0 or 1
entities, and the 0 case is now caught upstream before those functions are even
called with empty data.

**Alternatives considered**: Distinguishing "not found" from a generic network
failure was considered but rejected as out of scope — the spec's edge cases
scope this feature strictly to "documentId matches no entity", not to
general network-error UX (the existing silent-failure behavior on non-200
responses predates this feature and is not something this feature introduces
or worsens).

## 5. How does the local content cache stay tied to the active entity (FR-005)?

**Decision**: Extend the existing SQLite `cache` table (currently
`cache(lang TEXT, data TEXT)`) with a `documentId TEXT` column. `getData`'s
cache read becomes `SELECT data FROM cache WHERE lang=? AND documentId=?`
(passing the current `ACTIVE_ENTITY_DOCUMENT_ID`), and the write becomes
`DELETE FROM cache WHERE lang=?` (unchanged — still clears all locales' old rows
for simplicity) followed by an `INSERT` that includes the documentId. A device
that previously cached a different entity's data for the same language
therefore always misses the cache lookup after a switch (no matching row) and
falls through to the network fetch, naturally satisfying FR-005/User Story 4
without needing an explicit "invalidate on change" migration step.

**Rationale**: This is the minimal schema change that ties a cached row to the
specific entity it was fetched for, without adding a separate invalidation
pass or versioning scheme. `CREATE TABLE IF NOT EXISTS` alone only covers fresh
installs (a brand-new table already gets the `documentId` column); devices
upgrading from a pre-feature install already have the 2-column table, so
`getData` also runs `ALTER TABLE cache ADD COLUMN documentId TEXT` right after
the `CREATE TABLE IF NOT EXISTS`, wrapped in a try/catch that silently ignores
the "column already exists" error on every subsequent run. Either way, rows
cached before this migration end up with a NULL `documentId`, which never
matches the bound `ACTIVE_ENTITY_DOCUMENT_ID` parameter in the new `WHERE
lang=? AND documentId=?` lookup — the desired "invalidate old cache" outcome,
with no explicit invalidation code path to maintain.

**Alternatives considered**: Wiping the entire local cache table whenever the
constant changes (e.g., via a version flag) was considered but rejected as
more moving parts for the same outcome — the `documentId`-aware lookup already
achieves "never reuse another entity's cached data" as a side effect of its
normal query, with no extra invalidation code path to maintain.

## 6. Scope boundary: what this feature does NOT touch

- **Analytics segmentation by entity** — out of scope (belongs to the
  already-planned Fase 4 / `005-analytics-dashboard-multi-entidade`).
- **Downloaded media file cache** (`FileHelper`'s per-language local media
  folder) — out of scope; not mentioned by the spec's FR-005, which scopes
  cache invalidation to the SQLite metadata cache only. Media re-fetches
  naturally once the filtered API returns the new entity's (different) media
  URLs.
- **Runtime, visitor-facing museum switching** — explicitly out of scope per
  the spec's Assumptions; this feature is a build/deploy-time operator
  control only.
- **General network-failure UX** (non-200 responses, timeouts) — pre-existing
  behavior, not introduced or altered by this feature.
