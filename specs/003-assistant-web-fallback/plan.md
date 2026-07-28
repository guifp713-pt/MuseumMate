# Implementation Plan: Assistant General-Knowledge Fallback

**Branch**: `003-assistant-web-fallback` | **Date**: 2026-07-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-assistant-web-fallback/spec.md`

> **Pivot note (2026-07-27):** the "additional Gemini call with Google Search
> grounding" this plan describes was **replaced before shipping** by a plain
> general-knowledge call (no grounding, no billing) — grounding returns 429
> without an active billing account this deployment won't enable. See
> `research.md §1/§2`. The plan's two-call topology, classification fields, kill
> switch, catalog precedence and analytics-event design all stand unchanged; only
> the second call's mechanism and the concrete names changed
> (`answerFromKnowledge` / no tool / `KNOWLEDGE_FALLBACK_ENABLED` /
> `usedGeneralKnowledge` / `assistant_knowledge_fallback`).

## Summary

Extend the existing assistant backend (feature 001) so that when a visitor's
question is clearly about the museum but the catalog has nothing relevant to
answer it, the assistant performs one additional, scoped Gemini call that
answers from the model's own general knowledge (see pivot note — originally
Google Search grounding), rather than immediately admitting it has no
information. The existing catalog-only structured call (`assistant-ai.ts`'s
`ask()`) is extended — not replaced — with two new response fields
(`catalogSufficient`, `searchTopic`) so the backend can decide, from the same
single call it already makes today, whether a second fallback call is
warranted. Catalog content always wins on conflict; the off-domain decline
guardrail (feature 001, User Story 2) is untouched and still runs entirely
inside the first call. A new backend-only kill switch
(`KNOWLEDGE_FALLBACK_ENABLED`) lets an operator disable the whole capability
instantly without a code change. The mobile app gains one new response field
(`usedGeneralKnowledge`) it renders as a visible "general knowledge, outside the
catalog" indicator, and a client-side, elapsed-time-based "still thinking…" swap
on the existing typing indicator — no new backend-to-client signal is introduced
for that. One new analytics `eventType` (`assistant_knowledge_fallback`)
captures every fallback attempt (confident or not) for future catalog-gap analysis.

## Technical Context

**Language/Version**: Backend addition in TypeScript (Node.js `>=20.0.0 <=24.x.x`, matching the existing Strapi 5 app — unchanged from feature 001). Mobile addition in QML/JS (Qt 6, C++17 toolchain) — no new C++ code.

**Primary Dependencies**: No new dependency in either stack. Backend reuses the already-installed `@google/genai` (`^2.12.0`) and the already-pinned `gemini-3.1-flash-lite` model, adding its built-in Google Search grounding tool (`tools: [{ googleSearch: {} }]`) to a second call. Mobile reuses `AssistantHandler.js`'s existing `XMLHttpRequest` pattern.

**Storage**: No new persistent storage. `analytics-event`'s `eventType` enum gains one additive value (`assistant_web_fallback`) — no migration of existing rows, matching the additive-schema discipline feature 001 already established for its own three `eventType` values.

**Testing**: None automated (neither stack has a test suite yet, per Constitution's Development Workflow & Quality Gates). Manual end-to-end verification via `quickstart.md`.

**Target Platform**: Backend: existing Node.js/Strapi server. Mobile: Android (arm64-v8a, armeabi-v7a) and Desktop, via the existing Qt Quick app — unchanged from features 001/002.

**Project Type**: Existing two-project monorepo (`backend/` + `TourAssistent-main/`, communicating over HTTP) — no new project introduced.

**Performance Goals**: SC-001 (this feature) — web-fallback answers within ~20s, vs. feature 001's unchanged 10s target for catalog-only answers (the fast path is untouched, since the second call only runs for the "museum-related but uncovered" subset of questions).

**Constraints**: The web-fallback call must never let external content override catalog content on conflict (FR-008); the constructed search must stay scoped to the active museum, verified post-hoc via `groundingMetadata.webSearchQueries` since native Google Search grounding doesn't accept a caller-supplied query string (research.md §4); the whole capability must be disable-able via one central switch (FR-011); the response contract extension must be strictly additive (NFR-3.4); server-side timeouts for the (now two, sequential) calls must stay strictly less than the mobile client's single request timeout, which must be raised accordingly (research.md §6).

**Scale/Scope**: One extended existing AI service function (`assistant-ai.ts`'s `ask()`, two new schema fields) + one new function in the same file (`searchWeb`) + one new backend config file (`config/assistant.ts`) + orchestration changes in the existing `assistant.ts` controller (no new route) + one additive enum value on the existing `analytics-event` schema + two edited mobile files (`AssistantHandler.js`, `ChatIAPanel.qml`) for the new response field, the external-source indicator, and the client-side "searching…" heuristic. No new content-type, no new endpoint, no new screen.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Environment Configuration Discipline | The new kill switch must not become a second drifting hardcoded value across files. | **PASS** — `WEB_FALLBACK_ENABLED` lives in exactly one new file (`backend/app/src/config/assistant.ts`), backend-only; the mobile app has no code path that needs its own copy, since it only ever renders whatever `usedWebSearch` the backend's response already carries (research.md §8). No duplication is introduced. |
| II. Cross-Stack Consistency | The extended response shape must stay centralized, not re-interpreted ad hoc. | **PASS** — `AssistantHandler.js` remains the sole parser of `AssistantAskResponse`; the new `usedWebSearch` field is read the same defensive way as the existing `autoTranslated`/`onTopic` fields, with no new normalization pattern introduced (research.md §10). |
| III. Simplicity / YAGNI | No speculative abstractions, frameworks, or plugins beyond present need. | **PASS** — reuses the existing AI provider and model rather than adding a new search-API dependency (research.md §1); the "searching…" indicator is a client-side elapsed-time heuristic rather than a new streaming/SSE mechanism (research.md §6); catalog-priority arbitration reuses the same call rather than adding a third reconciliation round-trip (research.md §7); no rate limiter beyond the kill switch, matching feature 001's existing no-rate-limit stance for the same reasons. |
| IV. Maintainable Design | New/changed components keep clear, focused responsibilities. | **PASS** — `searchWeb` is a new, separately-named function in `assistant-ai.ts` alongside (not merged into) `ask()`; the kill switch gets its own single-responsibility config file rather than being folded into `config/museum.ts`'s unrelated entity-selection concern (research.md §8); the controller's added orchestration branch is a straightforward extension of its existing try/catch structure, not a rewrite. |
| V. Spec-Driven Development | Proceeding via specify → clarify → plan, one feature in flight. | **PASS** — this plan follows the clarified `spec.md` (three clarifications resolved 2026-07-27); no other feature is concurrently in implementation. |

No violations — Complexity Tracking table is not needed. The two-call topology
for the "museum-related but uncovered" branch is the minimum necessary
complexity to satisfy the spec's own explicit ordering requirement (try
catalog first, only search when the catalog is confirmed insufficient, and
still let catalog win on conflict) — a single-call design cannot express that
ordering, so this is not treated as a Principle III violation requiring
justification.

## Project Structure

### Documentation (this feature)

```text
specs/003-assistant-web-fallback/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── assistant-api-web-fallback.md  # Phase 1 output — delta over 001's contract
└── tasks.md              # Phase 2 output (/speckit-tasks — not created by this command)
```

### Source Code (repository root)

```text
backend/app/src/config/
└── assistant.ts                        # new — exports WEB_FALLBACK_ENABLED (single backend-side
                                         #        kill switch, FR-011)

backend/app/src/api/assistant/
├── services/
│   ├── assistant-ai.ts                 # edited — ask()'s RESPONSE_SCHEMA gains catalogSufficient
│   │                                   #          + searchTopic; new exported searchWeb() using the
│   │                                   #          Google Search grounding tool + groundingMetadata
│   │                                   #          scope check
│   └── assistant-catalog.ts            # unchanged
└── controllers/
    └── assistant.ts                    # edited — orchestrates the optional second call, new
                                         #          WEB_SEARCH_TIMEOUT_MS, writes assistant_web_fallback
                                         #          instead of assistant_question on that branch

backend/app/src/api/analytics-event/content-types/analytics-event/schema.json
    # eventType enum gains one additive value: assistant_web_fallback

TourAssistent-main/
├── AssistantHandler.js                 # edited — parses new usedWebSearch field; REQUEST_TIMEOUT_MS
│                                        #          raised per research.md §6
└── ChatIAPanel.qml                     # edited — messagesModel gains usedWebSearch column + new
                                         #          external-source indicator text; typing indicator
                                         #          gains an elapsed-time "searching…" state
```

**Structure Decision**: Existing two-project monorepo (`backend/` Strapi app +
`TourAssistent-main/` Qt Quick app, per `CLAUDE.md`) — no new top-level
project. No new content-type, no new Strapi route: this feature only extends
the existing `assistant` custom API's service/controller layer and the
existing `analytics-event` schema, plus the two mobile files feature 001
already introduced for the assistant UI.

## Complexity Tracking

> No Constitution Check violations — this section is intentionally empty.
