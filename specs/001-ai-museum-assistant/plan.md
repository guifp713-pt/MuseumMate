# Implementation Plan: AI Museum Assistant

**Branch**: `001-ai-museum-assistant` | **Date**: 2026-07-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-ai-museum-assistant/spec.md`

## Summary

Add a text-based, museum-scoped AI assistant reachable from the mobile app's
HomePage (a chat-panel shell for it already exists but is unwired). A new
Strapi backend endpoint (`POST /api/assistant/ask`) holds the AI provider
call (Google Gemini API) server-side — never exposing a provider key to
the mobile client — builds a system prompt from the full localized museum
catalog (small enough at ~30 items/~10 areas to include in full, per the
spec's own retrieval-strategy assumption) plus an off-topic-refusal
instruction, and returns a structured `{ answer, autoTranslated, onTopic }`
response in one call. The mobile app wires the existing chat-panel shell
(`HomePage.qml`'s `recChat`) into a real conversation UI backed by a new
`AssistantHandler.js`, keeping the whole conversation in an in-memory QML
property (never persisted, cleared only when the app process ends) so it
survives closing/reopening the panel within a session but not across app
restarts. The backend also writes one lightweight analytics-event row per
interaction (question/decline/error), never containing message text.

## Technical Context

**Language/Version**: Backend addition in TypeScript (Node.js `>=20.0.0 <=24.x.x`, matching the existing Strapi 5 app); mobile addition in QML/JS (Qt 6, C++17 toolchain) — no new C++ code needed.

**Primary Dependencies**: Backend: `@google/genai` (new dependency) alongside the existing Strapi 5 stack. Mobile: no new dependency — reuses `XMLHttpRequest` and `QtQuick.LocalStorage` patterns already present in `ApiHandler.js`/`AnalyticsHandler.js`.

**Storage**: N/A new persistent storage. The assistant conversation is in-memory only on the client (never written to `QtQuick.LocalStorage`, per FR-009). The backend is stateless per request; it reads the existing Strapi/SQLite-backed catalog read-only and writes to the existing `analytics-event` collection (schema extended with three new `eventType` enum values — see `data-model.md`).

**Testing**: None automated (neither stack has a test suite yet, per Constitution's Development Workflow & Quality Gates). Manual end-to-end verification via `quickstart.md`.

**Target Platform**: Backend: Node.js server (existing Docker Compose / local `strapi develop` setup). Mobile: Android (arm64-v8a, armeabi-v7a) and Desktop, via the existing Qt Quick app.

**Project Type**: Web + mobile (existing two-project monorepo — `backend/` and `TourAssistent-main/`, communicating over HTTP; no new project/repo is introduced).

**Performance Goals**: SC-001 — relevant answers within 10s. SC-006 — connection-error message shown within 5s of send attempt.

**Constraints**: Offline-capable failure handling (FR-008, distinguishing "no internet" from "AI service unavailable"); no conversation persistence beyond the app session (FR-009) but must survive panel close/reopen within a session (clarified); rate limiting, if any, must never block a message (clarified); AI provider selection has no data-residency constraint (clarified) but the provider key must never reach the mobile client; catalog stays small enough (~30 items/~10 areas) that a full-catalog-in-system-prompt strategy is viable without retrieval infrastructure.

**Scale/Scope**: One new backend custom API (`api::assistant` — route + controller + service, ~3 small files), one extended existing content-type schema (enum addition, no migration of existing rows), one new mobile JS module (`AssistantHandler.js`), one new QML component (`ChatIAPanel.qml`, extracted from the existing inline `recChat` stub in `HomePage.qml`) plus wiring into `HomePage.qml` and `resources.qrc`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Environment Configuration Discipline | New mobile module (`AssistantHandler.js`) must not add a third independent hardcoded `baseUrl` alongside the two that already exist in `ApiHandler.js`/`AnalyticsHandler.js`. | **PASS** — `AssistantHandler.js` imports `ApiHandler.js`'s `baseUrl` rather than declaring its own (Research §10). Backend's `GEMINI_API_KEY` is read from an environment variable, not hardcoded; the AI model (`gemini-3.1-flash-lite` — see Research §2's implementation update) is intentionally hardcoded rather than externalized — Principle I calls for externalizing values that legitimately vary by deployment, and this version has no scenario that calls for a different tier (Research §2), so an env var would only add an accidental path to a costlier model. |
| II. Cross-Stack Consistency | New endpoint's response shape must be handled at a single, documented boundary rather than re-interpreted ad hoc. | **PASS** — `AssistantHandler.js` is the sole place that parses `AssistantAskResponse`; it is a flat custom-action response (not a Strapi entity), so there is no `data`/`attributes` wrapping ambiguity to normalize in the first place — documented in `contracts/assistant-api.md`. |
| III. Simplicity / YAGNI | No speculative abstractions, frameworks, or plugins beyond present need. | **PASS** — full-catalog-in-prompt instead of a retrieval/vector-search layer (Research §3); no rate-limiting code until real usage data justifies it (Research §6); no new Strapi plugin — a plain custom API route, matching the existing `analytics-event` custom-route pattern. |
| IV. Maintainable Design | New components have a clear, focused responsibility; avoid unnecessary abstraction. | **PASS** — backend split into route/controller/service (catalog-fetch, prompt-build, Gemini-call responsibilities separated); mobile chat UI extracted into its own `ChatIAPanel.qml` component rather than growing the already-large `HomePage.qml` further. |
| V. Spec-Driven Development | Proceeding via specify → clarify → plan, one feature in flight. | **PASS** — this plan follows the clarified `spec.md`; no other feature is concurrently in implementation. |

No violations — Complexity Tracking table is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-museum-assistant/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── assistant-api.md  # Phase 1 output
└── tasks.md              # Phase 2 output (/speckit-tasks — not created by this command)
```

### Source Code (repository root)

```text
backend/app/src/api/assistant/
├── routes/
│   └── 01-custom-assistant.ts     # POST /api/assistant/ask (auth: false)
├── controllers/
│   └── assistant.ts               # request validation, orchestrates service calls, writes analytics-event
└── services/
    ├── assistant-catalog.ts       # fetches + caches the localized catalog, serializes it for the prompt
    └── assistant-ai.ts            # builds the system prompt, calls @google/genai with structured output

backend/app/src/api/analytics-event/content-types/analytics-event/schema.json
    # eventType enum extended with assistant_question / assistant_decline / assistant_error

TourAssistent-main/
├── AssistantHandler.js            # new — builds requests to /api/assistant/ask, reuses ApiHandler.js's baseUrl
├── ChatIAPanel.qml                # new — extracted conversation UI (message list, input, send), replaces
│                                   #       the inline `recChat`/`recChatText` stub currently in HomePage.qml
├── HomePage.qml                   # edited — instantiates ChatIAPanel.qml in place of the old recChat stub
└── resources.qrc                  # edited — registers AssistantHandler.js and ChatIAPanel.qml
```

**Structure Decision**: This is the existing two-project monorepo (`backend/`
Strapi app + `TourAssistent-main/` Qt Quick app communicating over HTTP,
per `CLAUDE.md`) — no new top-level project is introduced. The backend
change is a new custom Strapi API following the same route/controller
pattern already established by `analytics-event`'s
`01-custom-analytics-event.ts`. The mobile change follows the existing
convention of one JS module per backend concern (`ApiHandler.js` for
catalog data, `AnalyticsHandler.js` for telemetry) plus one QML component
per UI concern, replacing the currently-inert `recChat` stub already
present in `HomePage.qml` (drag-to-close bottom sheet with a "Museum Mate
AI" header, currently backed only by a placeholder gray rectangle).
