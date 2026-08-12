# Phase 0 Research: Multi-Museum Analytics Segmentation

## 1. Shape of the attribution field on `analytics-event`

**Decision**: Add `entidadeDocumentId` as a plain `string` attribute on the existing
`analytics-event` schema (`backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`)
— **not** a Strapi relation to `api::entidade.entidade`.

**Rationale**: The schema's existing conventions for "which thing this event is about"
(`itemId`, `tourId`) are already plain denormalized integers, not relations — the event
record deliberately does not hold live references into content, it holds a stable identifier
snapshot. `documentId` is already the identifier used everywhere else in the codebase to name
"which museum" (feature 002's `ACTIVE_ENTITY_DOCUMENT_ID`, the mobile SQLite cache's
`documentId` column). A relation would require populating it on every read just to filter by
it, and Strapi relation filters compile to a join the flat-field filter (§4) doesn't need. A
plain string field also satisfies FR-004 (purely additive) and NFR-4.2 trivially: it is one
new nullable column, nothing existing changes shape.

**Alternatives considered**: A relation field (rejected — adds join overhead and a populate
requirement for no benefit, and breaks the schema's established flat-ID convention);
repurposing `metadata` (json) to carry the museum id instead of a first-class column (rejected
— `metadata` today is a genuinely free-form bag (`{ deviceId, source, os }` for mobile events,
`{ source: 'assistant' }` for assistant events); filtering Strapi REST queries by a key inside
a JSON blob is fragile and not idiomatic where a real column is available).

## 2. Mobile: avoiding a second, independently-maintained copy of the identifier

**Decision**: `AnalyticsHandler.js` gains `.import "ApiHandler.js" as Api` and reads
`Api.ACTIVE_ENTITY_DOCUMENT_ID` when building the event payload in `sendEvent()`. It does
**not** declare its own copy of the constant.

**Rationale**: This is a proven pattern already in the codebase, not a new idea:
`AssistantHandler.js` already does exactly this for `baseUrl` (`.import "ApiHandler.js" as
Api`, then `Api.baseUrl`), with a comment explicitly citing Constitution Principle I and
naming the goal as "não acrescentar uma terceira cópia independente ao problema já existente
entre ApiHandler/AnalyticsHandler." FR-002 asks for the same discipline applied to
`ACTIVE_ENTITY_DOCUMENT_ID`; reusing the identical mechanism keeps the two identifiers
(`baseUrl`, `ACTIVE_ENTITY_DOCUMENT_ID`) consistent in how they're shared, rather than
inventing a second sharing convention.

**Alternatives considered**: Passing the entity id as a parameter into every `sendEvent()`
call site instead of importing it inside `AnalyticsHandler.js` (rejected — `sendEvent()` is
called from many QML pages; threading one more parameter through every call site is more
change surface than importing the constant once, and it would let a call site pass the wrong
value by mistake, which importing does not).

## 3. Backend: attributing server-side assistant events

**Decision**: `assistant.ts`'s `writeAnalytics()` imports `ACTIVE_ENTITY_DOCUMENT_ID` from
`../../../config/museum` (the same relative import `assistant-catalog.ts` already uses) and
adds it to every event it creates. `writeAnalytics()` gains no new parameter for it — the
value is read directly from the config module, exactly like the catalog service already does,
since the backend only ever serves one active museum per deployment.

**Rationale**: This is the producer the original Fase 4 description (`FR-4.2`) did not name
(see spec.md FR-003) — `writeAnalytics()` is a second, independent path that creates
`analytics-event` rows (`assistant_question` / `assistant_decline` / `assistant_error` /
`assistant_knowledge_fallback`), entirely separate from the mobile app's `sendEvent()`. Without
this, every AI-usage event would ship unattributed, and US3's per-museum segmentation
(FR-013) would have nothing to segment by. Reading the constant directly (rather than passing
it as a request parameter) matches how the rest of the assistant backend already treats the
active museum as ambient configuration, not per-request state.

**Alternatives considered**: Deriving the museum id from the request/session instead of the
static config (rejected — the backend has no per-request museum concept anywhere else; the
whole assistant stack, including `assistant-catalog.ts`, already assumes one active museum
per running backend instance, per feature 002).

## 4. Filtering `analytics-event` reads by museum

**Decision**: `GET /api/analytics-events` gains `filters[entidadeDocumentId][$eq]=<documentId>`
alongside the existing pagination/sort params already used by `useAnalytics()` in
`HomePage.jsx`. Because it is a flat string field (§1), this is a single-condition equality
filter — no relation traversal involved.

**Rationale**: Directly satisfies FR-008 and NFR-4.3 ("filtering must occur in the request to
the server, never loading everything and filtering client-side"). No new endpoint is needed;
the existing core-generated `find` route already supports arbitrary `filters[...]` query
params on any attribute, which is exactly what feature 002 already relies on for `entidade`
filtering (`filters[documentId][$eq]=...` on `/api/entidades`) — the same idiom, one hop
lower in the data model.

**Alternatives considered**: A custom aggregation endpoint that pre-computes stats server-side
(rejected — FR-4.9 in the Fase 4 description explicitly frames this as "puramente de
agregação e visualização", i.e., keep computing stats client-side as today; a custom endpoint
would be new surface for no requirement that asks for it, violating Simplicity/YAGNI).

## 5. Filtering the item-name lookup by museum

**Decision**: `GET /api/items` for the name lookup (`carregarNomesDoStrapi` in `HomePage.jsx`)
gains a **deep relation filter**: `filters[area][map][entidade][documentId][$eq]=<documentId>`.
The fixed `pagination[pageSize]=100` single-page assumption is also replaced with the same
loop-until-`pageCount`-exhausted pattern `useAnalytics()` already uses for events, so the
lookup is correct even if a museum's own item count (unlikely, but not impossible) exceeds one
page.

**Rationale**: Inspection of the schemas shows `item` has **no direct relation to
`entidade`** — the only relation on `item` is `area` (`manyToOne`). The path to the owning
museum is three hops: `item → area (manyToOne) → map (manyToOne) → entidade (manyToOne)`.
Strapi's REST filtering supports filtering through nested relations by chaining bracket keys,
which is the standard mechanism for this and introduces no new dependency. Scoping the
*request* (not just post-filtering the result) satisfies FR-009's literal requirement, keeps
the payload proportional to one museum's catalogue (documented at ~30 items per museum,
`assistant-catalog.ts`'s Research §3), and — combined with the pagination fix — removes the
actual root cause of today's bug: a hardcoded `pageSize=100` with no regard for how many items
exist once a second museum's catalogue is summed with the first's.

**Alternatives considered**: Skip filtering and only fix the pagination cap, relying on the
fact that the top-items chart only ever needs names for item ids that already appear in the
selected museum's own events (rejected — it would still fetch and hold the other museum's
items in memory for no benefit, and does not satisfy FR-009's requirement that the *lookup
itself* be scoped, not just its eventual usage); a dedicated Strapi custom endpoint that joins
server-side (rejected — the same deep-filter capability already exists in the core REST API,
so a custom endpoint would duplicate a built-in capability, violating Simplicity/YAGNI).

## 6. The plugin's own network calls (removing the hardcoded host)

**Decision (revised during implementation — see Update below)**: The plugin's own **admin**
route (`/analytics-dashboard/active-entity`, §7) is called via Strapi's admin-provided
`useFetchClient()` hook from `@strapi/strapi/admin`. The three **Content API** calls
(`/api/entidades`, `/api/analytics-events`, `/api/items`) are called via a small local helper,
`fetchContentApi(path)`, built on plain `fetch()` against `window.strapi.backendURL` — the
same global Strapi's own `getFetchClient` implementation reads internally
(`node_modules/@strapi/admin/.../getFetchClient.mjs`) to discover its backend origin. Neither
path is a hardcoded string.

**Rationale**: `useFetchClient` is Strapi 5's standard mechanism for a plugin's admin-panel
frontend to call **admin-authenticated** routes (`/admin/...`, `/content-manager/...`, or a
plugin's own `type: 'admin'` routes): it resolves against wherever the admin panel is served
from and *always* attaches the current admin session's JWT
(`Authorization: Bearer <token>`, `getDefaultHeaders()` in `getFetchClient.mjs`). The three
Content API routes above are registered `auth: false` (public, matching feature 002's existing
`/api/entidades` filter contract and the mobile app's own anonymous calls) — but "not
requiring" auth is not the same as "ignoring a present-but-invalid one": sending an admin JWT
to a Content API route caused Strapi to reject the request with `401`, rather than silently
falling back to anonymous access. `window.strapi.backendURL` gives the same "no hardcoded
host" property as `useFetchClient` (FR-014 / Constitution Principle I) — it is the browser
global the admin app itself sets at startup with the same backend origin `useFetchClient`
reads — without attaching an admin token the Content API doesn't expect.

**Alternatives considered**: A new environment variable read by the plugin at build/runtime
(rejected — heavier than necessary; a global Strapi already exposes solves this, and
introducing a second config mechanism for what is a same-origin call would itself be a
Principle I violation in spirit, not a fix for one); making the three Content API routes
require Content API authentication instead (rejected — would diverge from the existing public
contract feature 002 already established for `/api/entidades`, and from the mobile app's own
anonymous calls, for no benefit).

> **Update (implementation, 2026-07-28):** the original decision above called
> `useFetchClient()` for *all four* endpoints, including the three Content API ones. This
> shipped and was caught during the user's own manual dashboard test: the browser network log
> showed `GET /api/entidades?...` returning `401`, while `GET /analytics-dashboard/active-entity`
> (the one genuinely admin-type route) returned `200` — exactly the asymmetry predicted by the
> rationale above once actually observed with a real admin session attached. Root-caused via
> `docker logs strapi_app` (Strapi's own request log line showed the `401`) and fixed by
> introducing `fetchContentApi` for the three Content API calls, keeping `useFetchClient` only
> for the one genuine admin route. Verified fixed via the same container's request log after
> rebuilding the plugin: all four endpoints returned `200`, including the 10s poll cycle.

## 7. Exposing "the currently active museum" to the dashboard (FR-017's default)

**Decision**: Add one route to the plugin's own already-scaffolded (but currently empty)
admin server routes (`server/src/routes/admin/index.js`), e.g.
`GET /analytics-dashboard/active-entity`, backed by a small controller/service function that
imports `ACTIVE_ENTITY_DOCUMENT_ID` from `../../../../../config/museum` (reachable from
plugin server code, since it runs in the same Strapi Node process) and returns
`{ documentId: string }`. `HomePage.jsx` calls this once on mount, via the same
`useFetchClient()` (§6), to pre-select the museum FR-017 requires as the default.

**Rationale**: The admin panel's React bundle cannot import a server-side TypeScript module
directly (it is a separately bundled browser SPA); some HTTP surface is required to expose a
server-side config value to it. The plugin already has an admin-type route table
(`type: 'admin'`, currently `routes: []`) scaffolded for exactly this purpose and unused —
filling it in is reusing existing structure rather than adding a new plugin or a new type of
surface. `type: 'admin'` (rather than `content-api`) is deliberately chosen so the route is
only reachable from within an authenticated admin session, matching where it is consumed.

**Alternatives considered**: Defaulting the selector to "whichever museum's `/api/entidades`
happens to sort first" (rejected — does not satisfy FR-017's literal requirement to default
to the *currently configured active* museum, and is arbitrary if museum ordering ever
changes); building this into the public `content-api` route instead (rejected — no non-admin
consumer needs this value; the narrower `admin` route type is the better-fitting existing
scaffold).

## 8. Populating the museum selector

**Decision**: The selector's list of museums comes from `GET /api/entidades?locale=pt&fields[0]=nameEntity&fields[1]=documentId`
(via the same `useFetchClient`), fetched once on mount alongside the active-entity lookup
(§7).

**Rationale**: `entidade` already has a human-readable, i18n-localized `nameEntity`. Filtering
to the two needed fields keeps the request minimal (Constitution Principle III) — no
populate of maps/areas/items/tours is needed for a selector that only shows a museum's name.
`locale=pt` is used because pt is the canonical, guaranteed-complete locale for every entity
in this project (per `assistant-catalog.ts`'s own documented reasoning for the same choice) —
an admin-facing dashboard label does not need to track the visitor's language.

**Alternatives considered**: Localizing the selector to the admin user's own language
(rejected — no such concept exists anywhere else in either stack today; introducing one here,
for a two-word museum-name label, would be speculative scope not asked for by any requirement).

## 9. Backfilling pre-existing events (FR-005)

**Decision**: A one-off Node script, `backend/app/scripts/backfill-analytics-entity.js`,
following the exact precedent already established by `scripts/translate-content.js`: it boots
its own Strapi instance via `strapiFactory` / `require('@strapi/strapi')`, is run manually once
(`node scripts/backfill-analytics-entity.js`) with the dev server stopped (SQLite allows one
writer), finds every `analytics-event` row where `entidadeDocumentId` is null/empty, and sets
it to the original fictional museum's documentId (the value already commented in
`config/museum.ts` — `gqag59gr2pvu95qawb4dq1ol`, "Industria Textil Norte").

**Rationale**: The project already has an established, working convention for exactly this
kind of one-time bulk data fix — `scripts/translate-content.js` and the two `fix-dictionary-*`
scripts under `backend/app/scripts/`. Reusing it is more consistent with the codebase than
introducing Strapi's formal Knex migration system (`database/migrations/`, currently empty)
for what is a single, one-time, manually-triggered correction rather than a repeatable
schema-versioned migration — per Constitution Principle III, the simplest solution that
correctly satisfies the requirement is preferred.

**Alternatives considered**: A Knex migration file under `database/migrations/` (rejected —
heavier machinery than the project uses anywhere else for a data fix, and migrations run
automatically on every boot, which is unnecessary risk for an operation that only ever needs
to run exactly once); doing the backfill by hand through the Strapi admin UI (rejected — not
practical at row-count scale, and not repeatable/verifiable the way a script is).

## 10. Assistant metrics: mapping existing events to four categories (FR-012)

**Decision**: The four required figures map directly onto the existing `eventType` enum with
**no** new interpretation of `success` needed beyond what the controller already guarantees:

| Figure | Query |
|---|---|
| Answered | `count(eventType == 'assistant_question')` |
| Refused as off-domain | `count(eventType == 'assistant_decline')` |
| Technical failure | `count(eventType == 'assistant_error')` |
| General-knowledge fallback used | `count(eventType == 'assistant_knowledge_fallback')` |

**Rationale**: Reading `controllers/assistant.ts` end-to-end confirms each `eventType` is
already written by exactly one code path with a fixed meaning: `assistant_question` is only
ever written with `success: true` (both the normal on-topic/catalog-sufficient path and the
kill-switch-off path use `onTopic` which is `true` whenever `assistant_question` is chosen);
`assistant_decline` only for off-domain refusals (`success: false`); `assistant_error` only
for the three failure paths (catalog load failure, model call failure/exception, server
timeout); `assistant_knowledge_fallback` only for the fallback path, regardless of whether the
model's `confident` flag ended up true or false (the comment in the controller is explicit
that this event type "cobre os quatro sub-caminhos acima... nunca só o sucesso" — i.e., a
non-confident fallback still counts as "fallback was used", which is exactly the catalog-gap
signal FR-4.11 / SC-008 want visible). This means the four figures are a plain group-by-count
over `eventType`, scoped by the same museum + period filters as every other metric on the
page — no new field, no new classification logic, satisfying FR-018 / NFR-4.5 exactly as
written ("MUST NOT require a new event kind or a change to how assistant events are
classified").

**Alternatives considered**: Further splitting the fallback figure into
confident-vs-not-confident sub-counts (rejected — FR-012 only requires these four categories
as a minimum; splitting further is not asked for by any requirement and can be added later
without a breaking change if it becomes useful, per Simplicity/YAGNI).

## 11. Disposition of `getLanguageStats` (FR-010)

**Decision**: Remove `getLanguageStats` (`analytics-event/controllers/analytics-event.ts`) and
its custom route (`analytics-event/routes/01-custom-analytics-event.ts`) entirely.

**Rationale**: Confirmed by repo-wide search that no client — mobile app or dashboard plugin —
calls `/analytics-events/language-stats`; the dashboard already computes its own language
distribution client-side (`calculateStats` in `HomePage.jsx`). An unused endpoint that
aggregates `session_id` across the whole table with no museum awareness at all is a bigger
future liability than a maintenance cost saved by scoping it: if anything starts calling it
later, it would silently return cross-museum figures unless someone remembers this feature's
constraint. FR-010 in the spec already frames this exact choice, resolved during clarification
in favor of removal (Simplicity/YAGNI: don't maintain code for a use case that doesn't exist).
