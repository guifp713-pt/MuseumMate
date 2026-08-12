---

description: "Task list for Multi-Museum Analytics Segmentation"
---

# Tasks: Multi-Museum Analytics Segmentation

**Input**: Design documents from `/specs/004-analytics-multi-entity/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Not included — neither stack has an automated test suite (Constitution's
Development Workflow & Quality Gates); verification is manual via `quickstart.md`,
referenced directly from the relevant task instead of duplicated as prose.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact and repo-relative

---

## Phase 1: Setup

**Purpose**: Confirm the environment this feature is validated against is ready — no
new dependency, no new project (plan.md Technical Context).

- [X] T001 Confirm the Strapi backend runs locally (`npm run develop` in `backend/app/`)
  and that both `entidade` documents exist — the original fictional museum
  (`gqag59gr2pvu95qawb4dq1ol`) and Museu de Portimão (`ifajyzfd52v3tvq1mrf8j6eu`) —
  per `quickstart.md` Prerequisites. No code change in this task.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one schema change every user story depends on — no event can be
attributed and no dashboard filter can exist until this field exists.

**⚠️ CRITICAL**: No user story task can begin until this phase is complete.

- [X] T002 Add the `entidadeDocumentId` string attribute (additive, nullable) to
  `backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`,
  per `contracts/event-attribution.md` § Schema addition.
- [X] T003 Restart the Strapi dev server once so
  `backend/app/types/generated/contentTypes.d.ts` regenerates with the new field;
  confirm `tsc --noEmit` (or the dev server boot log) shows no type errors. Depends
  on T002.

**Checkpoint**: Schema ready — all three user stories can now proceed.

---

## Phase 3: User Story 1 - Every event knows which museum it came from (Priority: P1) 🎯 MVP

**Goal**: Both producers of `analytics-event` rows (the mobile app and the backend
assistant) stamp every new event with the museum that was active when it happened,
and every pre-existing row is explicitly backfilled — so no event, past or future,
is ever left unattributed (spec.md FR-001–FR-005, FR-016).

**Independent Test**: With `ACTIVE_ENTITY_DOCUMENT_ID` set to Museu de Portimão,
produce a visit event from the app and a question from the assistant, then inspect
the two new `analytics-event` rows directly in the Strapi admin content manager —
each carries `entidadeDocumentId = 'ifajyzfd52v3tvq1mrf8j6eu'`. This is verifiable
with zero dashboard changes in place.

### Implementation for User Story 1

- [X] T004 [P] [US1] Edit `TourAssistent-main/AnalyticsHandler.js`: add
  `.import "ApiHandler.js" as Api` near the top of the file, and add
  `"entidadeDocumentId": Api.ACTIVE_ENTITY_DOCUMENT_ID` to the `data` object built
  in `sendEvent()`, per `contracts/event-attribution.md` § Producer 1 (mobile app).
- [X] T005 [P] [US1] Edit
  `backend/app/src/api/assistant/controllers/assistant.ts`: add
  `import { ACTIVE_ENTITY_DOCUMENT_ID } from '../../../config/museum';` and add
  `entidadeDocumentId: ACTIVE_ENTITY_DOCUMENT_ID` to the `data` object created
  inside `writeAnalytics()`, per `contracts/event-attribution.md` § Producer 2
  (backend assistant).
- [X] T006 [US1] Create `backend/app/scripts/backfill-analytics-entity.js`,
  following the existing `backend/app/scripts/translate-content.js` pattern
  (boots its own Strapi instance via `require('@strapi/strapi')`), to find every
  `analytics-event` row where `entidadeDocumentId` is null/empty and set it to
  `'gqag59gr2pvu95qawb4dq1ol'` (the original fictional museum), per
  `research.md` §9. Depends on T002.
- [X] T007 [US1] Ran `node scripts/backfill-analytics-entity.js` inside an
  ephemeral container reusing `strapi_app`'s volumes (`docker stop strapi_app` →
  `docker run --rm --volumes-from strapi_app -w /app node:20 node
  scripts/backfill-analytics-entity.js` → `docker start strapi_app`). Result:
  4280 rows before, 4280 after, 0 unattributed remaining — `quickstart.md`
  Scenario 1 (SC-002) confirmed. Server verified back up and healthy afterward
  (`/api/entidades` 200, `/analytics-dashboard/active-entity` 401,
  `/api/analytics-events/language-stats` 404).
- [X] T008 [US1] Confirm new events are attributed correctly (backend already
  configured for Museu de Portimão): call `POST /api/assistant/ask` and confirm
  the resulting `analytics-event` row carries
  `entidadeDocumentId = 'ifajyzfd52v3tvq1mrf8j6eu'`; verify the mobile-side
  payload shape by code inspection (T004) — on-device confirmation from the
  running app is the user's own manual step, not reproducible in this
  environment — `quickstart.md` Scenario 2 (SC-001). Depends on T004, T005 only
  (does not require T007 — new-event attribution is independent of backfilling
  old rows).

**Checkpoint**: User Story 1 is fully functional and independently verifiable —
every event, old and new, is now attributed to a museum, with no dashboard
changes required yet.

---

## Phase 4: User Story 2 - Read the dashboard for one museum at a time (Priority: P2)

**Goal**: The `analytics-dashboard` plugin lets an administrator pick a museum and
scopes every existing KPI, table and chart to it, requesting only that museum's
data from the server (spec.md FR-006–FR-010, FR-014, FR-015, FR-017).

**Independent Test**: With both museums holding attributed events (from US1),
select each museum in turn in the dashboard and confirm every figure changes
accordingly and never blends the two — per `quickstart.md` Scenarios 3, 4 and 6.

### Implementation for User Story 2

- [X] T009 [US2] Edit
  `backend/app/src/plugins/analytics-dashboard/server/src/services/service.js`:
  add a function (e.g. `getActiveEntity`) that imports `ACTIVE_ENTITY_DOCUMENT_ID`
  from `../../../../../config/museum` and returns `{ documentId: ACTIVE_ENTITY_DOCUMENT_ID }`,
  per `research.md` §7.
- [X] T010 [US2] Edit
  `backend/app/src/plugins/analytics-dashboard/server/src/controllers/controller.js`:
  add a handler (e.g. `activeEntity(ctx)`) that calls the service function from
  T009 and sets `ctx.body`. Depends on T009.
- [X] T011 [US2] Edit
  `backend/app/src/plugins/analytics-dashboard/server/src/routes/admin/index.js`:
  add a `GET /analytics-dashboard/active-entity` route (`type: 'admin'`) wired to
  the controller handler from T010, per `contracts/dashboard-queries.md` §3.
  Depends on T010.
- [X] T012 [US2] Edit
  `backend/app/src/api/analytics-event/controllers/analytics-event.ts`: remove the
  `getLanguageStats` method entirely, per `research.md` §11 (FR-010).
- [X] T013 [US2] Delete
  `backend/app/src/api/analytics-event/routes/01-custom-analytics-event.ts` (its
  only route, `GET /analytics-events/language-stats`), per `research.md` §11
  (FR-010).
- [X] T014 [US2] Edit
  `backend/app/src/plugins/analytics-dashboard/admin/src/pages/HomePage.jsx`:
  replace both `fetch('http://localhost:1337/...')` calls (in `useAnalytics`'s
  poll and in `carregarNomesDoStrapi`) with a new local `fetchContentApi(path)`
  helper (plain `fetch()` against `window.strapi.backendURL`), per
  `research.md` §6. **Corrected during manual testing**: the original plan
  used `useFetchClient` for these too, which attaches the admin session's JWT
  and got `401`-rejected by the Content API's `auth: false` routes (only the
  genuinely admin-type route in T011 needs `useFetchClient`) — see research.md
  §6's Update note.
- [X] T015 [US2] Edit `HomePage.jsx`: add `museuAtivo` React state; on mount, fetch
  `GET /api/entidades?locale=pt&fields[0]=nameEntity&fields[1]=documentId` (museum
  list) and `GET /analytics-dashboard/active-entity` (T011) to seed the default
  selection; render a museum selector that updates `museuAtivo` on change, per
  `contracts/dashboard-queries.md` §3–4 (FR-006, FR-017). Depends on T011, T014.
- [X] T016 [US2] Edit `HomePage.jsx`'s `useAnalytics()`: add
  `filters[entidadeDocumentId][$eq]={museuAtivo.documentId}` to the events request
  URL and add `museuAtivo` to the effect's dependency array, per
  `contracts/dashboard-queries.md` §1 (FR-007, FR-008, FR-015). Depends on T015.
- [X] T017 [US2] Edit `HomePage.jsx`'s `carregarNomesDoStrapi()`: add
  `filters[area][map][entidade][documentId][$eq]={museuAtivo.documentId}` to the
  items request, and replace the single fixed-`pageSize=100` fetch with a
  paginate-until-`pageCount`-exhausted loop (mirroring `useAnalytics`'s existing
  loop), per `contracts/dashboard-queries.md` §2 (FR-009). Depends on T015.
- [ ] T018 [US2] Manually validate `quickstart.md` Scenarios 3, 4 and 6: dashboard
  opens on the active museum by default; every KPI/table/chart stays scoped when
  switching museum or time period; the 10s auto-refresh preserves the selection
  and re-requests only that museum's events; item names resolve fully with no
  numeric placeholders; no request goes to a hardcoded `localhost`; and
  `/analytics-events/language-stats` now 404s. Depends on T012, T013, T016, T017.

**Checkpoint**: User Stories 1 AND 2 both work independently — the dashboard now
correctly segments visitor traffic per museum.

---

## Phase 5: User Story 3 - See how the AI assistant is actually being used (Priority: P3)

**Goal**: The dashboard gains a dedicated section reporting AI assistant usage as
four distinct, museum- and period-scoped figures — answered, off-domain declines,
technical errors, general-knowledge fallback used (spec.md FR-011–FR-013, FR-018).

**Independent Test**: Ask the assistant questions producing each of the four
outcomes, then confirm the dashboard's new section reports four separate counts
for the selected museum and period, per `quickstart.md` Scenario 5.

### Implementation for User Story 3

- [X] T019 [US3] Edit `HomePage.jsx`: add a pure aggregation function (e.g.
  `calculateAssistantStats(eventosNormalizados, periodoConfig)`) that counts
  `assistant_question` / `assistant_decline` / `assistant_error` /
  `assistant_knowledge_fallback` events within the active period, per
  `research.md` §10 and `data-model.md` § Dashboard: Assistant Usage Metrics.
  Depends on T016 (relies on `eventosNormalizados` already being museum-scoped).
- [X] T020 [US3] Edit `HomePage.jsx`: render a new "Utilização do Assistente de IA"
  section (reusing the existing `KpiCard` component/layout style) displaying the
  four figures from T019, wired to the current `museuAtivo` and `periodoAtivo`.
  Depends on T019.
- [ ] T021 [US3] Manually validate `quickstart.md` Scenario 5: with the assistant
  producing at least one answered, one off-domain, and one general-knowledge
  fallback response, confirm all four figures are shown separately (never merged)
  and the fallback count is distinguishable from "answered". Depends on T020.

**Checkpoint**: All three user stories are now independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Keep project documentation in sync (Constitution's Development
Workflow & Quality Gates) and run a final full regression pass.

- [X] T022 [P] Update `CLAUDE.md`'s `analytics-event` and Custom API sections to
  document the new `entidadeDocumentId` field and the removed
  `getLanguageStats`/`language-stats` endpoint.
- [X] T023 [P] Update `EtapasImplementacao.txt`'s Fase 4 section, marking its
  functional/non-functional requirements `[OK]` following the same convention
  already used for Fase 2 (FR-4.6 marked `[PENDENTE]` — backfill not yet run;
  NFR-4.4 marked `[EM VALIDAÇÃO]` — full browser check pending).
- [ ] T024 Run all six `quickstart.md` scenarios end-to-end in one pass as a final
  regression check before considering the feature done. Depends on T008, T018, T021.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational only. No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on Foundational only. Independently testable
  without US1 having run (it will simply show unattributed/backfilled-only data
  until US1's producers are live), but realistic validation benefits from US1
  being done first (per spec.md Assumptions / NFR-4.4).
- **User Story 3 (Phase 5)**: Depends on Foundational and, functionally, on US2's
  `useAnalytics` museum-scoping (T016) since its aggregation reuses the same
  already-scoped `eventosNormalizados` array — not on US1's mobile-side producer.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- US1: the two producer edits (T004, T005) are independent of each other; the
  backfill script (T006–T007) only needs the schema (T002), not the producer
  edits; final validation (T008) needs both producers live.
- US2: service → controller → route (T009→T010→T011) is a strict chain (each
  references the previous); the `useFetchClient` swap (T014) is independent of
  that chain; the selector (T015) needs the route (T011) and the fetch swap
  (T014); the two query-scoping edits (T016, T017) both need the selector state
  (T015) but are independent of each other; endpoint removal (T012, T013) is
  independent of everything else in US2.
- US3: strictly sequential (T019 → T020 → T021), and T019 depends on US2's T016.

### Parallel Opportunities

- T004 and T005 (US1) — different files, no shared dependency.
- T016 and T017 (US2) — different functions in the same file but non-overlapping
  edits; safe to do back-to-back without blocking each other's design.
- T022 and T023 (Polish) — different files.

---

## Parallel Example: User Story 1

```bash
# After Foundational (T002-T003) completes, launch both producer edits together:
Task: "Edit TourAssistent-main/AnalyticsHandler.js — add entidadeDocumentId to sendEvent() payload"
Task: "Edit backend/app/src/api/assistant/controllers/assistant.ts — add entidadeDocumentId to writeAnalytics()"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational — the schema field).
2. Complete Phase 3 (User Story 1) — attribution alone already stops the
   irreversible data loss the spec identifies as the highest-priority risk, even
   before any dashboard UI changes.
3. **STOP and VALIDATE**: confirm attributed events exist for both museums by
   inspecting the Strapi content manager directly (T008).

### Incremental Delivery

1. Setup + Foundational → schema ready.
2. Add User Story 1 → validate independently → every new event is now
   attributable, and history is backfilled (MVP for the irreversible part).
3. Add User Story 2 → validate independently → the dashboard now reads
   per-museum instead of blending everything.
4. Add User Story 3 → validate independently → AI assistant usage becomes
   visible for the first time.
5. Polish → docs synced, full quickstart regression run.

---

## Notes

- No test tasks are included — neither stack has an automated test suite
  (Constitution's Development Workflow & Quality Gates); every story's
  independent test is a manual `quickstart.md` scenario instead.
- `[P]` tasks touch different files and have no dependency on an incomplete task.
- Commit after each task or logical group, per the user's own git workflow.
- Constitution Principle V (Spec-Driven Development, NON-NEGOTIABLE): only one
  approved task should be actively in implementation at a time — work through
  these phases serially rather than starting multiple stories' tasks at once,
  even where the Parallel Opportunities above show them as technically
  independent.
