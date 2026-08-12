# Data Model: Multi-Museum Analytics Segmentation

No new Strapi content-type is introduced. This document covers the one new schema
attribute, the two existing content-types this feature reads through (unchanged in
shape, newly filtered), and the one new derived view the dashboard computes.

## Analytics Event (`analytics-event`) — changed

Existing content-type
(`backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`).
One new attribute added; nothing existing is removed or renamed (FR-004, NFR-4.2).

| Field | Type | Notes |
|---|---|---|
| `eventType` | enumeration | Existing, unchanged. Includes `assistant_question` / `assistant_decline` / `assistant_error` / `assistant_knowledge_fallback` since feature 001/003. |
| `timestamp` | datetime | Existing, unchanged. |
| `sessionId` | string | Existing, unchanged. |
| `language` | enumeration | Existing, unchanged. |
| `itemId` | integer | Existing, unchanged. |
| `tourId` | integer | Existing, unchanged. |
| `success` | boolean | Existing, unchanged. |
| `metadata` | json | Existing, unchanged (`{ deviceId, source, os }` for mobile events; `{ source: 'assistant' }` for assistant events). |
| `entidadeDocumentId` | string (new) | The `documentId` of the `entidade` (museum) this event belongs to — the same value as `ACTIVE_ENTITY_DOCUMENT_ID` at the moment the event was recorded (research.md §1). Nullable at the schema level (additive change, FR-004), but always populated by both producers going forward (FR-002, FR-003) and backfilled for every pre-existing row (FR-005, see below). |

**Producers** (both now stamp this field — see research.md §2/§3):
- Mobile app: `TourAssistent-main/AnalyticsHandler.js`, `sendEvent()` — reads
  `Api.ACTIVE_ENTITY_DOCUMENT_ID` via `.import "ApiHandler.js" as Api`.
- Backend assistant: `backend/app/src/api/assistant/controllers/assistant.ts`,
  `writeAnalytics()` — reads `ACTIVE_ENTITY_DOCUMENT_ID` from `config/museum.ts`.

**Backfill** (FR-005, research.md §9): a one-off script sets
`entidadeDocumentId = 'gqag59gr2pvu95qawb4dq1ol'` (the original fictional museum,
per `config/museum.ts`'s own comment) on every row where the field is currently
null/empty. Run once, after the schema change deploys and before the dashboard's
museum filter goes live, so no pre-existing row is ever silently excluded from
every museum's view at once.

**Post-rollout unattributed events** (FR-016): not expected in practice — no
outdated mobile app build remains in the field. If an event nonetheless arrives
without `entidadeDocumentId` after this feature ships, it is treated as a defect
signal (logged clearly), not routed into any museum's statistics by convention.

## Museum Entity (`entidade`) — unchanged in shape, newly read for two purposes

Existing content-type, no schema change. This feature reads it for:

1. **The dashboard's museum selector** — `GET /api/entidades?locale=pt&fields[0]=nameEntity&fields[1]=documentId`
   (research.md §8). Read-only; nothing here is written back to `entidade`.
2. **The item-name lookup's scoping** — the deep relation filter
   `filters[area][map][entidade][documentId][$eq]=...` on `GET /api/items`
   (research.md §5) traverses through `entidade` without querying it directly.

## Item (`item`) — unchanged in shape, newly filtered

Existing content-type. Confirmed relation path to its owning museum:
`item.area (manyToOne) → area.map (manyToOne) → map.entidade (manyToOne)`. No
direct `item → entidade` relation exists. The name-lookup query
(`carregarNomesDoStrapi` in `HomePage.jsx`) is changed to filter through this
chain and to paginate fully instead of assuming a single fixed-size page
(research.md §5) — no schema change, only a query-shape change.

## Dashboard: Selected Museum (new, admin-panel UI state only)

Not persisted anywhere — transient React state in `HomePage.jsx`, analogous to
the existing `periodoAtivo` state.

| Field | Type | Notes |
|---|---|---|
| `museuAtivo` (selected museum) | `{ documentId: string, nameEntity: string }` | Defaults, on mount, to whichever museum `GET /analytics-dashboard/active-entity` (research.md §7) reports as currently configured (FR-017). Changed only by the administrator via the new museum selector (FR-006). Every derived figure (`calculateStats`, `buildChartData`, `buildTopItemsChartData`, the new assistant-metrics aggregation) is recomputed from this value, the same way they already recompute from `periodoAtivo` today. |

## Dashboard: Assistant Usage Metrics (new, derived — not persisted)

A pure aggregation over the same `eventosNormalizados` array `calculateStats`
already consumes, filtered to the four assistant `eventType` values and to the
active museum + period (research.md §10). No new content-type, no new stored
field — this is a read-time projection, exactly like `calculateStats` itself.

| Field | Type | Notes |
|---|---|---|
| `answered` | integer | `count(eventType == 'assistant_question')` in the active museum + period. |
| `declinedOffDomain` | integer | `count(eventType == 'assistant_decline')`. |
| `technicalErrors` | integer | `count(eventType == 'assistant_error')`. |
| `knowledgeFallbackUsed` | integer | `count(eventType == 'assistant_knowledge_fallback')`. |

## Removed: `getLanguageStats` custom endpoint (FR-010)

`backend/app/src/api/analytics-event/controllers/analytics-event.ts`'s
`getLanguageStats` method and its route
(`analytics-event/routes/01-custom-analytics-event.ts`,
`GET /analytics-events/language-stats`) are deleted, not migrated forward — see
research.md §11. No data model is associated with it going forward.
