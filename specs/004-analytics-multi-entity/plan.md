# Implementation Plan: Multi-Museum Analytics Segmentation

**Branch**: `004-analytics-multi-entity` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-analytics-multi-entity/spec.md`

## Summary

Every `analytics-event` row is anonymous as to which museum produced it, and the
`analytics-dashboard` plugin has no notion of museum at all — it always reads and
aggregates every event and every item, globally. This feature (1) adds a flat
`entidadeDocumentId` field to `analytics-event`, stamped by both event producers
(the mobile app's `AnalyticsHandler.js` and the backend assistant's
`writeAnalytics()`) from the same centrally configured identifier feature 002
already established, with a one-off script backfilling every pre-existing row to
the original fictional museum; (2) adds a museum selector to the dashboard,
scopes every existing metric/chart/query to it via server-side filters (a flat
filter on events, a three-hop relation filter — `item → area → map → entidade`
— on the item-name lookup), and replaces the plugin's two hardcoded
`http://localhost:1337` calls with Strapi's admin `useFetchClient`; and (3) adds
a new assistant-usage section to the dashboard, aggregating the four
already-recorded assistant `eventType` values (no new event kind, no new
classification logic) into distinct answered/declined/error/fallback figures.
Also removes one unused, museum-unaware custom endpoint (`getLanguageStats`,
FR-010) rather than scoping it forward.

## Technical Context

**Language/Version**: Backend addition in TypeScript (Node.js `>=20.0.0
<=24.x.x`, Strapi 5.48). Dashboard-plugin addition in JavaScript/JSX (React, via
Strapi's bundled admin build tooling — no new frontend framework). Mobile
addition in QML/JS (Qt 6, no new C++ code).

**Primary Dependencies**: No new dependencies in any stack. Reuses
`strapi.documents(...)` (backend), the Strapi core REST `find` route's existing
`filters[...]` query-param support (both flat and nested-relation filters,
already exercised elsewhere in the codebase — feature 002's
`filters[documentId][$eq]`), `@strapi/strapi/admin`'s `useFetchClient` (already
imported once in `App.jsx`, previously unused for data fetching), and the
existing `.import "ApiHandler.js" as Api` QML pattern already proven by
`AssistantHandler.js`.

**Storage**: `better-sqlite3` (Strapi default) — one additive nullable `string`
column on the existing `analytics_events` table, no migration framework
introduced (the one-off backfill uses the project's existing "standalone
Node script boots its own Strapi instance" convention — `research.md` §9 —
not `database/migrations/`, which stays empty). No change to the mobile app's
local SQLite cache/offline-queue schema (`analytics_cache` table) — the payload
gains one JSON field, which is schema-less from SQLite's point of view (FR-004).

**Testing**: None automated on either stack (per Constitution's Development
Workflow & Quality Gates). Manual end-to-end verification via `quickstart.md`,
using both real `entidade` documents (fictional + Museu de Portimão) to
validate genuine cross-museum segmentation rather than an artificially
duplicated entity (per spec's Assumptions / Fase 4 → NFR-4.4).

**Target Platform**: Backend: existing Node.js/Strapi server (local `strapi
develop` / Docker Compose). Dashboard: Strapi admin panel, served by and
browsed against that same backend (no separate deployable). Mobile: Android
(arm64-v8a, armeabi-v7a) and Desktop, via the existing Qt Quick app.

**Project Type**: Existing two-project monorepo (`backend/` +
`TourAssistent-main/`) — no new project. Within `backend/`, all dashboard work
stays inside the existing `analytics-dashboard` plugin; no new plugin is
introduced.

**Performance Goals**: SC-004 (museum switch fully reflected within 3s, no page
reload); SC-005 (a second museum's data must not slow down reading the first
museum's dashboard — achieved by filtering server-side rather than
client-side, so each museum's own request stays proportional to its own event
count).

**Constraints**: Additive schema only (FR-004/NFR-4.2) — the mobile offline
cache/retry path must keep working unmodified for payloads built before this
feature shipped. Museum scoping must not degrade the existing 100-events-per-
page pagination or the 10-second polling refresh (FR-015/NFR-4.3) — filtering
happens in the request, never by discarding rows after fetching everything.
Assistant metrics must require no new event kind and no reclassification of
existing events (FR-018/NFR-4.5) — pure aggregation over what already exists.

**Scale/Scope**: Two museums today (fictional + Museu de Portimão), expected to
stay in the single digits (spec Assumptions) — the selector needs no
search/pagination. One new schema field, one new admin-only plugin route, one
new one-off backfill script, changes to two existing dashboard queries plus one
new assistant-metrics aggregation function, changes to two existing event
producers (mobile + backend), one endpoint removed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Environment Configuration Discipline | No new hardcoded environment value; existing ones fixed or reused, never duplicated. | **PASS** — `entidadeDocumentId` is always sourced from the one existing `ACTIVE_ENTITY_DOCUMENT_ID` per stack (research.md §2/§3), never a new copy. The dashboard's two hardcoded `http://localhost:1337` calls are removed in favor of `useFetchClient` (research.md §6) — this feature *fixes* an existing Principle I violation rather than adding one. The new admin-only `active-entity` route (research.md §7) exposes a value, it does not introduce a second config location for it. |
| II. Cross-Stack Consistency | Response-shape handling stays centralized, not re-interpreted ad hoc. | **PASS** — `entidadeDocumentId` follows the schema's existing flat-ID convention (`itemId`, `tourId`), so no new response-shape handling is introduced anywhere; `normalizeEvent` in `HomePage.jsx` gains one more passthrough field, not a new parsing branch. |
| III. Simplicity / YAGNI | No speculative abstraction beyond present need. | **PASS** — no new plugin, no generic "multi-tenant" framework, no aggregate "all museums" view (FR-017, resolved against building one), no cross-museum comparison UI (Out of Scope). The unused `getLanguageStats` endpoint is deleted rather than kept "just in case" (FR-010). The backfill reuses the project's existing one-off-script convention instead of introducing Strapi's migration system for a single one-time fix. |
| IV. Maintainable Design | Clear, focused responsibility per component. | **PASS** — the new assistant-metrics aggregation is a pure function following the exact shape `calculateStats`/`buildChartData`/`buildTopItemsChartData` already establish (input: normalized events + period + museum; output: derived figures), not a new architectural pattern. The new admin route has the single responsibility of exposing one config value. |
| V. Spec-Driven Development | Proceeding via specify → clarify (resolved inline) → plan → tasks → implement, one feature in flight. | **PASS** — this plan follows the approved, fully-clarified `spec.md` (all three `[NEEDS CLARIFICATION]` markers resolved before planning began); `/speckit-tasks` follows this plan before implementation starts. |

No violations — Complexity Tracking table is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/004-analytics-multi-entity/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
└── contracts/
    ├── event-attribution.md    # Phase 1 output
    └── dashboard-queries.md    # Phase 1 output
    # tasks.md — Phase 2 output (/speckit-tasks), not created by this command
```

### Source Code (repository root)

```text
backend/app/src/api/analytics-event/
├── content-types/analytics-event/schema.json   # edited — adds entidadeDocumentId (string, additive)
├── controllers/analytics-event.ts               # edited — getLanguageStats removed (FR-010)
└── routes/01-custom-analytics-event.ts          # deleted — its only route

backend/app/src/api/assistant/controllers/
└── assistant.ts                        # edited — writeAnalytics() imports ACTIVE_ENTITY_DOCUMENT_ID
                                         #          from config/museum and stamps every event it creates

backend/app/src/plugins/analytics-dashboard/server/src/
├── routes/admin/index.js               # edited — adds GET /analytics-dashboard/active-entity
├── controllers/controller.js           # edited — handler for the route above
└── services/service.js                 # edited — reads ACTIVE_ENTITY_DOCUMENT_ID from config/museum

backend/app/src/plugins/analytics-dashboard/admin/src/pages/
└── HomePage.jsx                        # edited — museum selector state + fetch; both hardcoded
                                         #          localhost fetches replaced with useFetchClient;
                                         #          events/items queries gain museum filters; item
                                         #          query gains full pagination; new assistant-metrics
                                         #          aggregation + section; getLanguageStats caller
                                         #          removed (there was none — confirms FR-010 is dead code)

backend/app/scripts/
└── backfill-analytics-entity.js        # new — one-off script, run once (research.md §9)

TourAssistent-main/
└── AnalyticsHandler.js                 # edited — .import "ApiHandler.js" as Api; sendEvent() payload
                                         #          gains entidadeDocumentId: Api.ACTIVE_ENTITY_DOCUMENT_ID
```

**Structure Decision**: Existing two-project monorepo (`backend/` Strapi app +
`TourAssistent-main/` Qt Quick app) — no new top-level project, no new Strapi
plugin. All backend-admin work stays inside the already-existing
`analytics-dashboard` plugin; all mobile work stays inside the already-existing
`AnalyticsHandler.js`, following the same `.import` pattern `AssistantHandler.js`
already established for sharing `ApiHandler.js`'s `baseUrl`.

## Complexity Tracking

No violations — this section is intentionally left empty (Constitution Check
above shows a full PASS on all five principles).
