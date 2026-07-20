---

description: "Task list for AI Museum Assistant"
---

# Tasks: AI Museum Assistant

**Input**: Design documents from `/specs/001-ai-museum-assistant/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/assistant-api.md, quickstart.md (all present)

**Tests**: Not included — neither stack has an automated test suite (Constitution: Development Workflow & Quality Gates); `quickstart.md` is the manual verification path, folded into Phase 6.

**Organization**: Tasks are grouped by user story (US1/US2/US3, matching `spec.md`'s P1/P2/P3) to enable independent implementation and testing of each.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact and repo-relative

## Path Conventions

Existing two-project monorepo (no new project introduced):
- Backend: `backend/app/src/api/assistant/` (new custom API) + `backend/app/src/api/analytics-event/` (schema extension)
- Mobile: `TourAssistent-main/` (new `AssistantHandler.js`, new `ChatIAPanel.qml`, edited `HomePage.qml` and `resources.qrc`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the new backend dependency and scaffold the new API's file layout.

- [ ] T001 Install `@google/genai` as a dependency in `backend/app/package.json` (run `npm install @google/genai` from `backend/app/`)
- [ ] T002 [P] Add a `GEMINI_API_KEY` entry to `backend/app/.env`, following the existing convention for other secrets in that file
- [ ] T003 [P] Scaffold empty files for the new API in `backend/app/src/api/assistant/`: `routes/01-custom-assistant.ts`, `controllers/assistant.ts`, `services/assistant-catalog.ts`, `services/assistant-ai.ts`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infrastructure every user story needs — the extended analytics schema, the route/validation skeleton, and the mobile chat-panel shell (extracted from the existing inert stub) with its entry point already wired.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Extend the `eventType` enum in `backend/app/src/api/analytics-event/content-types/analytics-event/schema.json` with three new values: `assistant_question`, `assistant_decline`, `assistant_error`
- [ ] T005 Define `POST /api/assistant/ask` (`auth: false`) in `backend/app/src/api/assistant/routes/01-custom-assistant.ts`, following the existing pattern in `backend/app/src/api/analytics-event/routes/01-custom-analytics-event.ts`
- [ ] T006 Implement request validation in `backend/app/src/api/assistant/controllers/assistant.ts`: `message` (1–2000 chars after trim), `language` (one of `pt`/`en`/`es`/`fr`), `sessionId` (required string); on failure return `400 { "error": "invalid_request", "message": "<detail>" }` per `contracts/assistant-api.md`
- [ ] T007 [P] Extract the inline `recChat`/`recChatText` stub (`TourAssistent-main/HomePage.qml` lines ~2785–2971) into a new `TourAssistent-main/ChatIAPanel.qml` component: message list area, text input + send control, and a persistent "Messages are processed by AI" notice near the input (FR-013) — preserve the existing drag-to-close `MouseArea` and `anchors.bottomMargin` slide/`Behavior` animation as-is
- [ ] T008 Instantiate `ChatIAPanel.qml` in `TourAssistent-main/HomePage.qml` in place of the old `recChat` `Rectangle`, keeping the existing `chatIAPageVisible`/`chatButtonIA` open trigger and the header "x" / drag-to-close handlers wired to the new component (depends on T007)
- [ ] T009 [P] Register `TourAssistent-main/ChatIAPanel.qml` and the new `TourAssistent-main/AssistantHandler.js` (from T010) in `TourAssistent-main/resources.qrc`
- [ ] T010 [P] Create `TourAssistent-main/AssistantHandler.js`: import `ApiHandler.js`'s existing `baseUrl` constant (per Research §10 — do not declare a third independent copy) and stub an `askAssistant(message, language, sessionId, history, onSuccess, onNetworkError, onServiceError)` function with `XMLHttpRequest` wiring modeled on the existing pattern in `AnalyticsHandler.js`

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Ask about anything in the museum, in your own language (Priority: P1) 🎯 MVP

**Goal**: A visitor asks about any item, area, or tour in the catalog (not just what's currently on screen) and gets a correct, same-language text answer — using the official Strapi translation when one exists, or an AI-generated translation (flagged as such) when it doesn't.

**Independent Test**: With the app language set to each of PT/EN/ES/FR in turn, open the assistant from the HomePage, ask a question whose answer exists in the catalog, and confirm a correct, same-language text answer — including for catalog content unrelated to the screen the visitor was last on.

### Implementation for User Story 1

- [ ] T011 [P] [US1] Implement `backend/app/src/api/assistant/services/assistant-catalog.ts`: fetch the full localized catalog (entidade → tours/items/maps/areas/dictionary) for a given language, reusing the populate shape `ApiHandler.js` already queries, with an in-process per-language cache with a 5-minute TTL (Research §3)
- [ ] T012 [US1] Implement `backend/app/src/api/assistant/services/assistant-ai.ts`: serialize the catalog into a system prompt instructing the model to (a) prefer official catalog translations over generating new ones (FR-005/FR-006), (b) say it doesn't have the information rather than inventing an answer when the catalog has nothing relevant (FR-012), then call `@google/genai`'s `gemini-2.0-flash-lite` with `responseMimeType: "application/json"` and a `responseSchema` for `{ answer, autoTranslated, onTopic }` (Research §5); explicitly include the received `history` turns in the Gemini call as prior conversation turns (e.g. via the SDK's multi-turn `contents` array, oldest → newest, ahead of the current `message`) so follow-up questions resolve using in-session context (FR-014) — this is not left to interpretation at implementation time (depends on T011)
- [ ] T013 [US1] Implement the `ask` controller action in `backend/app/src/api/assistant/controllers/assistant.ts`: call the catalog + AI services with `message`/`language`/`history`, return `200 { answer, autoTranslated, onTopic }` on success, race the Gemini call against an explicit **~6s server-side timeout** (deliberately shorter than the mobile client's ~8s timeout, so the backend wins the race and returns a structured error — Research §7) mapping AI-call failures to `502` and timeout to `504` (both `{ "error": "assistant_unavailable" }`), and write an `assistant_question` analytics-event row (`metadata: { "source": "assistant" }`, never message/answer text) after a successful on-topic call (depends on T012, T006)
- [ ] T014 [US1] Implement `askAssistant` in `TourAssistent-main/AssistantHandler.js`: POST `{ message, language, sessionId, history }` to `/api/assistant/ask` and parse the `{ answer, autoTranslated, onTopic }` response into the success/error callbacks (depends on T010, T013)
- [ ] T015 [US1] Implement the send flow in `TourAssistent-main/ChatIAPanel.qml`: append the visitor's message to the in-memory `messages` list, call `AssistantHandler.askAssistant` with the current message/active language/session id, append the assistant's reply, and show a subtle "Automatic translation" indicator on replies where `autoTranslated` is `true` (FR-015) (depends on T014, T007)
- [ ] T016 [US1] In `TourAssistent-main/HomePage.qml`'s `ChatIAPanel.qml` instantiation (from T008), bind the new component's active-language property to `HomePage.qml`'s existing `linguaEscolhidaHome` property (already correctly populated end-to-end from `main.qml`'s `linguaEscolhida` via `WelcomePage.qml`'s `linguaEscolhidaWelcome` — confirmed in code, no `main.qml`/`WelcomePage.qml` changes needed) so every assistant request uses the visitor's currently active app language without requiring them to specify one (FR-004) (depends on T015)

**Checkpoint**: User Story 1 is fully functional and independently testable — catalog-grounded, same-language, correctly-flagged answers across all four languages.

---

## Phase 4: User Story 2 - Assistant stays on-topic (Priority: P2)

**Goal**: Off-topic questions are declined with a redirect to museum topics instead of being answered; mixed questions get the museum-related part answered and the rest declined.

**Independent Test**: Ask an off-topic question (no connection to the museum, its exhibits, or visiting it) and confirm the assistant declines and redirects, without attempting to answer the unrelated part.

### Implementation for User Story 2

- [ ] T017 [US2] Add the museum-domain definition and off-topic refusal instruction to the system prompt in `backend/app/src/api/assistant/services/assistant-ai.ts`, including guidance to answer the museum-related part and decline the rest of a mixed question (FR-003, Research §4) (depends on T012)
- [ ] T018 [US2] In `backend/app/src/api/assistant/controllers/assistant.ts`, branch the analytics write on the `onTopic` flag: write `assistant_decline` (`success: false`) instead of `assistant_question` when `onTopic` is `false`, while still returning `200` with the populated decline text (depends on T013)
- [ ] T019 [US2] Confirm `TourAssistent-main/ChatIAPanel.qml` renders `onTopic: false` replies as an ordinary assistant message (no distinct error styling) — a decline is a normal populated answer, not a failure (depends on T015)

**Checkpoint**: User Stories 1 AND 2 both work independently — off-topic questions declined and redirected, mixed questions partially answered.

---

## Phase 5: User Story 3 - Reach the assistant from the HomePage (Priority: P3)

**Goal**: A visitor can start and continue a conversation from the HomePage without navigating elsewhere, gets a clear "no internet" vs. "service unavailable" distinction on failure, and prior in-session messages survive closing/reopening the panel.

**Independent Test**: From the HomePage, open the assistant, send a message, and receive a response without leaving the HomePage flow; separately, with no internet connection, confirm a clear error is shown instead of a silent failure.

### Implementation for User Story 3

- [ ] T020 [P] [US3] Implement an ~8s client-side request timeout in `TourAssistent-main/AssistantHandler.js`'s `askAssistant`, distinguishing `xhr.onerror` (no route to host → "needs an internet connection" message, FR-008) from a timeout or non-`200` response (→ "service unavailable" message) via separate callbacks (depends on T010)
- [ ] T021 [US3] Surface the two distinct error states from T020 as messages in `TourAssistent-main/ChatIAPanel.qml` without adding a broken assistant turn to the conversation, per `contracts/assistant-api.md`'s client behavior note (depends on T020, T015)
- [ ] T022 [US3] Implement a retry action in `TourAssistent-main/ChatIAPanel.qml` for messages with `status: "error"`: re-invoke `AssistantHandler.askAssistant` with the same message text, active language, and history, setting that message's `status` back to `"sending"` for the duration of the retry (per spec.md's Edge Case "the visitor sees a connection-error message and can retry once connectivity returns" and `data-model.md`'s Assistant Message `status` field) (depends on T021)
- [ ] T023 [US3] Add the client-side empty/whitespace-message guard in `TourAssistent-main/ChatIAPanel.qml`: do not call `askAssistant` for an empty/whitespace-only message and prompt the visitor to type a question instead (depends on T015)
- [ ] T024 [US3] Include the last 20 turns of `ChatIAPanel.qml`'s in-memory `messages` as `history` (`{ role, text }` pairs) in each `AssistantHandler.askAssistant` request so follow-up questions resolve correctly using in-session context (FR-014) (depends on T015)
- [ ] T025 [US3] Verify `ChatIAPanel.qml`'s `messages` property survives the panel's existing hide/show (`bottomMargin` slide) cycle so reopening the assistant view within the same app session shows prior messages (clarified reopen behavior, FR-009); adjust only if the T007/T008 extraction changed the component's lifecycle (depends on T008, T015)
- [ ] T026 [US3] In `backend/app/src/api/assistant/controllers/assistant.ts`, write an `assistant_error` analytics-event row (`success: false`) when the catalog fetch fails, the AI call errors or times out, or the structured response fails to parse (depends on T013)

**Checkpoint**: All three user stories are independently functional per spec.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation and a final consistency pass — no automated test suite exists for this repo, so this phase is the primary quality gate.

- [ ] T027 [P] Run the full `quickstart.md` manual validation (Scenarios 1–4) across all four languages and confirm all 8 numbered expectations hold
- [ ] T028 [P] Verify `analytics-event` rows for `assistant_question`/`assistant_decline`/`assistant_error` contain only `{ "source": "assistant" }` in `metadata` and never the visitor's question or the assistant's answer text (FR-016), via the Strapi admin panel or the `analytics-dashboard` plugin
- [ ] T029 Re-check Constitution Principle I compliance: confirm `AssistantHandler.js` declares no independent `baseUrl` (imports `ApiHandler.js`'s) and `GEMINI_API_KEY` is read from the environment, never hardcoded

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion — no dependency on US2/US3
- **User Story 2 (Phase 4)**: Depends on Foundational completion; T017/T018 extend the same files US1 built (T012/T013), so US2 implementation starts after US1's corresponding tasks land, even though it is independently testable once done
- **User Story 3 (Phase 5)**: Depends on Foundational completion; T020/T021/T022/T024/T025/T026 extend files US1 built (T010/T013/T015), so likewise proceeds after the relevant US1 tasks land
- **Polish (Phase 6)**: Depends on all three user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other stories — the MVP
- **User Story 2 (P2)**: Independently testable once implemented, but its tasks are small deltas to files US1 created (`assistant-ai.ts`, `assistant.ts`, `ChatIAPanel.qml`)
- **User Story 3 (P3)**: Independently testable once implemented, but its tasks are likewise deltas to files US1 created

### Within Each User Story

- Catalog/AI services before the controller action
- Controller action before the mobile handler
- Mobile handler before the chat-panel UI wiring
- Story complete before moving to the next priority (recommended for a single-developer flow; see Parallel Team Strategy below for multi-developer)

### Parallel Opportunities

- T002, T003 (Setup) can run in parallel with each other
- T007, T009, T010 (Foundational) touch different files and can run in parallel
- T011 (US1 catalog service) has no same-file conflicts and can start in parallel with Foundational's mobile tasks (T007–T010), since it only depends on Setup
- T020 (US3 timeout) can start as soon as T010 (AssistantHandler.js skeleton) exists, in parallel with US1/US2 work, since it doesn't depend on the ask endpoint being finished
- T027, T028 (Polish) can run in parallel with each other

---

## Parallel Example: Foundational Phase

```bash
Task: "Extract recChat stub into TourAssistent-main/ChatIAPanel.qml"                # T007
Task: "Register ChatIAPanel.qml and AssistantHandler.js in resources.qrc"           # T009
Task: "Create TourAssistent-main/AssistantHandler.js skeleton"                      # T010
```

## Parallel Example: User Story 1

```bash
Task: "Implement backend/app/src/api/assistant/services/assistant-catalog.ts"       # T011
# (T012 depends on T011's exports, so it follows rather than running in parallel)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run Scenario 1 of `quickstart.md` across all four languages
5. Demo if ready — this alone delivers the core "ask the museum anything" value

### Incremental Delivery

1. Setup + Foundational → chat panel opens/closes, entry point wired, backend route validates input
2. Add User Story 1 → real Q&A works → Demo (MVP)
3. Add User Story 2 → off-topic declines work → Demo
4. Add User Story 3 → connectivity errors, follow-ups, and reopen-persistence all verified → Demo
5. Polish → full `quickstart.md` sign-off

### Parallel Team Strategy

Given how small this feature is (3 backend files + 2 mobile files, per `plan.md`'s Scale/Scope), a two-person split works better than three:

1. Both complete Setup + Foundational together
2. Developer A: `assistant-catalog.ts` + `assistant-ai.ts` + `assistant.ts` controller (backend side of US1/US2/US3)
3. Developer B: `AssistantHandler.js` + `ChatIAPanel.qml` wiring (mobile side of US1/US2/US3), working against the contract in `contracts/assistant-api.md` while Developer A's endpoint is still in progress
4. Integrate and run Phase 6 together

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No automated tests exist for either stack (Constitution: Development Workflow & Quality Gates) — `quickstart.md` (Phase 6) is the verification gate
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
- T017/T018/T020/T021/T022/T024/T025/T026 deliberately edit files earlier stories created rather than introducing parallel new files — this matches the feature's small, tightly-coupled scope (one endpoint, one chat panel) rather than forcing artificial independence
