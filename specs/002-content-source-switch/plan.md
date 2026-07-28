# Implementation Plan: Active Museum Entity Selection

**Branch**: `002-content-source-switch` | **Date**: 2026-07-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-content-source-switch/spec.md`

## Summary

Both the mobile app (`ApiHandler.js`) and the assistant backend
(`assistant-catalog.ts`) currently fetch **every** `entidade` row from Strapi and
implicitly use whichever one comes first (`dados[0]` / the full `entities` array
respectively) — there is no filtering by entity today. This feature introduces one
centrally defined **Active Museum Configuration** constant per stack (documentId
of the `entidade` to serve), adds a server-side `filters[documentId][$eq]=...`
query to both the mobile app's existing `/api/entidades` REST call and the
backend's `assistant-catalog` Strapi query, and handles the two states that
filtering by ID newly makes possible: zero matches (misconfiguration → blocking
error screen, never a crash or an empty screen) and a changed ID (existing local
SQLite cache must be invalidated, not silently reused). Per the constant's default
value, the app always has a valid entity to show under normal operation; the
"not found" path is reachable only through an explicit operator misconfiguration.

## Technical Context

**Language/Version**: Mobile addition in QML/JS (Qt 6, C++17 toolchain, no new C++ code). Backend addition in TypeScript (Node.js `>=20.0.0 <=24.x.x`, matching the existing Strapi 5 app).

**Primary Dependencies**: No new dependencies in either stack — reuses the existing `XMLHttpRequest` + `QtQuick.LocalStorage` patterns in `ApiHandler.js`, and the existing `strapi.documents(...)` query API already used by `assistant-catalog.ts`.

**Storage**: Mobile: existing SQLite `cache` table (via `QtQuick.LocalStorage`), schema extended with a `documentId` column so a cached row is only served back when it matches the currently configured active entity (FR-005). Backend: no schema change — `assistant-catalog.ts`'s in-process 5-minute cache (keyed by language) is unaffected because it always re-derives from the one configured documentId; no per-entity cache key is needed since only one entity is ever queried.

**Testing**: None automated (neither stack has a test suite yet, per Constitution's Development Workflow & Quality Gates). Manual end-to-end verification via `quickstart.md`, using the second real museum entity currently being populated in parallel (per user's own manual test plan: change the configured documentId, rebuild, confirm the app switches to the other museum's content).

**Target Platform**: Backend: existing Node.js/Strapi server (Docker Compose / local `strapi develop`). Mobile: Android (arm64-v8a, armeabi-v7a) and Desktop, via the existing Qt Quick app.

**Project Type**: Existing two-project monorepo (`backend/` + `TourAssistent-main/`, communicating over HTTP) — no new project introduced.

**Performance Goals**: N/A beyond existing behavior — filtering happens as an added Strapi query-param on calls that already exist; no new round trips.

**Constraints**: The configured active-entity documentId MUST always default to a known-valid `entidade` (clarified) — the misconfiguration/"not found" path must only ever be reached through an explicit operator error, never as a default/idle state. The two configuration owning-locations (one per stack — see Constitution Check, Principle I) must never be edited independently of each other; switching museums means updating both to the same value.

**Scale/Scope**: Two single-constant additions (one per stack) + one query-param addition on two existing Strapi queries (mobile REST call, backend `assistant-catalog` query) + one SQLite schema/cache-key change (mobile) + one new blocking error state in `main.qml`. No new content-types, no new endpoints, no new screens beyond the one error state.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Environment Configuration Discipline | The active-entity documentId must not become a second `baseUrl`-style problem (hardcoded and drifting across multiple files). | **PASS** — exactly one owning location per stack: `ApiHandler.js` (mobile, already the sole owner of `baseUrl`) and a new tiny `backend/app/src/config/museum.ts` (backend), imported by `assistant-catalog.ts` rather than inlined, so if a second backend consumer ever needs it, it imports the same constant instead of redeclaring it. Two owning locations (not one) is unavoidable — the mobile app and the Strapi backend are separate deployables that cannot share a single runtime file — but each stack internally has a single source, and Research §1 documents the operator discipline for keeping the two values equal. |
| II. Cross-Stack Consistency | Response-shape handling must stay centralized, not re-interpreted ad hoc. | **PASS** — no new response shape is introduced; the existing `dados[0].attributes \|\| dados[0]` normalization in `ApiHandler.js` and the existing `documentId`-indexing in `assistant-catalog.ts` are reused unchanged. Filtering only narrows which rows Strapi returns, it doesn't change their shape. |
| III. Simplicity / YAGNI | No speculative abstraction beyond present need. | **PASS** — no new plugin, no generic "multi-entity switcher" UI (out of scope per spec's Assumptions — runtime visitor-facing museum switching is a later capability, not this feature). The backend config file is a single exported constant, not a config framework. |
| IV. Maintainable Design | Clear, focused responsibility per component. | **PASS** — `museum.ts` has the single responsibility of holding the active documentId; `assistant-catalog.ts` and `ApiHandler.js` keep their existing responsibilities, only gaining a filter parameter and a not-found path. |
| V. Spec-Driven Development | Proceeding via specify → clarify → plan, one feature in flight. | **PASS** — follows the clarified `spec.md`; per explicit user direction, this feature skips the standalone `/speckit-checklist`, `/speckit-tasks`, and `/speckit-analyze` steps (scope judged too small to need a separate task breakdown) and goes directly from this plan to implementation. |

No violations — Complexity Tracking table is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/002-content-source-switch/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/
    └── active-entity-config.md  # Phase 1 output
    # No tasks.md — skipped by explicit user direction (feature judged too small)
```

### Source Code (repository root)

```text
backend/app/src/config/
└── museum.ts                          # new — exports ACTIVE_ENTITY_DOCUMENT_ID (single backend-side source of truth)

backend/app/src/api/assistant/services/
└── assistant-catalog.ts               # edited — filters findMany() by ACTIVE_ENTITY_DOCUMENT_ID; throws a
                                        #          distinguishable "entity not found" error when the filter matches nothing

TourAssistent-main/
├── ApiHandler.js                      # edited — new ACTIVE_ENTITY_DOCUMENT_ID constant (single mobile-side source
                                        #          of truth, alongside the existing baseUrl); getData() adds
                                        #          filters[documentId][$eq]=... to the /api/entidades URL; cache
                                        #          table gains a documentId column/check (FR-005); getData()'s
                                        #          success callback distinguishes "0 entities returned" from
                                        #          normal data so main.qml can show the blocking error state
└── main.qml                           # edited — new `entityConfigError` property + blocking full-screen error
                                        #          state shown instead of the language-selection screen when
                                        #          carregarDados() reports no matching entity
```

**Structure Decision**: Existing two-project monorepo (`backend/` Strapi app +
`TourAssistent-main/` Qt Quick app, per `CLAUDE.md`) — no new top-level project.
No new content-type, no new Strapi route/controller: this feature only adds a
query-time filter and a small config constant to code paths that already exist
in both stacks, plus one new error-display state in the mobile UI.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
