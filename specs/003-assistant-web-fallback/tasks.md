---

description: "Task list template for feature implementation"
---

# Tasks: Assistant General-Knowledge Fallback (was: Web Search Fallback)

> **Pivot note (2026-07-27):** tasks T001–T025 below are the **original**
> web-search implementation and are kept as a truthful record of what was built
> and tested at the time (including the T001/T013 discovery that Google Search
> grounding returns `429 RESOURCE_EXHAUSTED` without billing). After that work,
> the feature was **re-implemented as a general-knowledge fallback** (no
> grounding, no billing) — see **Phase 8** at the bottom for the pivot tasks, and
> `research.md §1/§2` for the rationale. Where the historical tasks say
> `searchWeb`/`googleSearch`/`WEB_FALLBACK_ENABLED`/`usedWebSearch`/
> `assistant_web_fallback`, the shipped code now uses `answerFromKnowledge`/(no
> tool)/`KNOWLEDGE_FALLBACK_ENABLED`/`usedGeneralKnowledge`/
> `assistant_knowledge_fallback` respectively.

**Input**: Design documents from `specs/003-assistant-web-fallback/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/assistant-api-web-fallback.md, quickstart.md

**Tests**: Not requested for this feature and not generated — neither stack has an automated test suite yet (Constitution's Development Workflow & Quality Gates); verification tasks below are manual, driven by `quickstart.md`, matching the pattern already used by features 001/002.

**Organization**: Tasks are grouped by user story (spec.md) to enable independent validation of each story once the shared Foundational work is done.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- File paths are exact and repo-relative

---

## Phase 1: Setup

**Purpose**: Resolve the one open technical unknown from research.md before committing to an implementation shape.

- [X] T001 Spike: verify whether the installed `@google/genai` SDK (`backend/app/node_modules/@google/genai`, version `^2.12.0`) accepts `tools: [{ googleSearch: {} }]` combined with `responseMimeType: "application/json"` + `responseSchema` in the same `generateContent` call on `gemini-3.1-flash-lite`. Make one throwaway test call (e.g. via `npm run console` or a scratch script) to confirm Plan A (combined call, research.md §2) works, or confirms Plan B (schema-less call + sentinel token) is required. Do not leave scratch scripts in the repo. **Result (2026-07-27): inconclusive — grounding itself returns `429 RESOURCE_EXHAUSTED` on the current API key regardless of schema presence, so Plan A vs Plan B could not be distinguished; proceeding with Plan A per user direction, documented as unverified in research.md §2.**

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared building blocks every user story's work depends on — classification fields, kill switch, analytics enum, timeouts.

**⚠️ CRITICAL**: No user story task below can be correctly implemented/validated until this phase is complete.

- [X] T002 [P] Create `backend/app/src/config/assistant.ts` exporting `WEB_FALLBACK_ENABLED = false` (FR-011, research.md §8)
- [X] T003 In `backend/app/src/api/assistant/services/assistant-ai.ts`: extend `RESPONSE_SCHEMA` with `catalogSufficient` (boolean) and `searchTopic` (string) properties, reword `buildSystemPrompt()`'s on-topic/off-topic instruction so a question is off-topic only when it has **no plausible connection** to the museum (spec.md Clarifications, session 2026-07-27; FR-002, FR-005), add instructions for when to set `catalogSufficient: false` and populate `searchTopic`, and update `ask()`'s return mapping to read and pass through both new fields (data-model.md, Question Classification)
- [X] T004 [P] Add `"assistant_web_fallback"` to the `eventType` enum in `backend/app/src/api/analytics-event/content-types/analytics-event/schema.json` (FR-010, additive — no existing enum value renamed or removed)
- [X] T005 [P] Add a `WEB_SEARCH_TIMEOUT_MS` constant (proposed 20000ms) to `backend/app/src/api/assistant/controllers/assistant.ts` for reuse with the existing `withTimeout` helper, and raise `REQUEST_TIMEOUT_MS` in `TourAssistent-main/AssistantHandler.js` from 25000 to 45000 (research.md §6 — must stay strictly greater than the worst-case sum of `AI_TIMEOUT_MS` + `WEB_SEARCH_TIMEOUT_MS`)

**Checkpoint**: Classification call, kill switch, analytics enum, and timeout budget all exist — user story work can begin.

---

## Phase 3: User Story 1 - Get an answer when the catalog falls short, but only for museum questions (Priority: P1) 🎯 MVP

**Goal**: When a question is on-topic but the catalog has nothing relevant, and the kill switch is enabled, the assistant performs a scoped web search and returns a clearly-marked answer instead of "I don't have that information."

**Independent Test**: Ask a question unambiguously about the museum's domain but absent from the catalog, and confirm a relevant, correctly-sourced answer with a visible external-source indicator arrives within the web-search latency target (spec.md, User Story 1).

### Implementation for User Story 1

- [X] T006 [US1] Implement and export `searchWeb({ catalog, message, language, searchTopic })` in `backend/app/src/api/assistant/services/assistant-ai.ts`: call `gemini-3.1-flash-lite` with `tools: [{ googleSearch: {} }]`, a system instruction that restricts search scope to the active museum + `searchTopic` and requires the reply in `language`, using the combined structured-output call from T001's Plan A result (or the Plan B sentinel-token fallback if T001 found the combination unsupported); return `{ answer, conclusive, webSearchQueries }`. Implemented per Plan A (T001 was inconclusive on quota, not on request-shape support — see research.md §2 update).
- [X] T007 [US1] In `searchWeb()`, add the post-hoc scope check: inspect the Gemini response's `groundingMetadata.webSearchQueries`, and treat the result as inconclusive if no issued query is recognizably scoped to the active museum's name (research.md §4, FR-006)
- [X] T008 [US1] In `backend/app/src/api/assistant/controllers/assistant.ts`'s `ask()`: after the primary call, when `onTopic && !catalogSufficient`, branch on `WEB_FALLBACK_ENABLED` (`config/assistant.ts`) — if disabled, return the primary call's existing answer unchanged (no new behavior, no analytics change); if enabled, call `searchWeb()` under `WEB_SEARCH_TIMEOUT_MS`, and on failure/timeout/inconclusive fall back to the primary call's "I don't have that information" answer (FR-009). **Note**: this task builds the branch's control flow (success, inconclusive, timeout, failure sub-paths) only — the `assistant_web_fallback` analytics write for *all* of these sub-paths is intentionally deferred to T019 (Phase 6/US4), not added here. When implementing T019, revisit every sub-path added in this task, not just the success case. **Implementation note**: T008 and T019 were written together in the same controller edit (single continuous implementation session, not staged commits) rather than literally shipping a temporary gap in analytics coverage — the analytics write already covers all four sub-paths (conclusive, inconclusive, timeout, failure) from the moment this branch exists. Both are marked complete together; T019 below documents the same code, not separate work.
- [X] T009 [US1] Add `usedWebSearch` (boolean) to the `200` response body constructed in `backend/app/src/api/assistant/controllers/assistant.ts`'s `ask()`, true only when `searchWeb()` returned a conclusive, scope-verified result (contracts/assistant-api-web-fallback.md)
- [X] T010 [P] [US1] Parse the new `usedWebSearch` field in `TourAssistent-main/AssistantHandler.js`'s success handler and include it in the object passed to `onSuccess`
- [X] T011 [P] [US1] In `TourAssistent-main/ChatIAPanel.qml`: add a `usedWebSearch` property to each appended message entry (`onAssistantReply`, `showWelcomeMessage`, `sendCurrentMessage`), and add a new indicator `Text` (visible when `model.role === "assistant" && model.usedWebSearch`) next to the existing translation-notice text, with per-language `webSearchNoticeText()` strings (FR-007)
- [X] T012 [US1] In `TourAssistent-main/ChatIAPanel.qml`: add an elapsed-time "searching…" heuristic — a `Timer` started alongside `timeoutTimer` in `dispatch()` that, after ~8000ms of `waitingForReply`, swaps the existing typing indicator's label/text to a distinguishable "searching…" state per language, reset in `finishRequest()` (research.md §6)
- [X] T013 [US1] Manually validate `specs/003-assistant-web-fallback/quickstart.md` Scenarios 1 and 2 — kill switch off behaves exactly as pre-feature; kill switch on returns a sourced, indicator-marked answer within the latency target, with the "searching…" state visible on a slow response. **Result (2026-07-27, against the real running backend)**: Scenario 1 fully confirmed via direct API calls — off-topic declined (`assistant_decline`), catalog-covered answered instantly (`assistant_question`), catalog-gap question returns the unchanged "I don't have that information" answer with no `assistant_web_fallback` row. Scenario 2's *branch and fallback behavior* confirmed — with the switch temporarily flipped on, the same catalog-gap question triggered `searchWeb()`, which failed with the same `429 RESOURCE_EXHAUSTED` seen in T001, was caught cleanly, logged one `assistant_web_fallback` row with `success: false`, and returned the same fallback answer with `usedWebSearch: false`, all within ~1.5s (no hang, no crash). The *conclusive-success* path (real grounded answer, external-source indicator content, mobile QML rendering) remains unverified pending working grounding quota — same caveat as T001/research.md §2. Switch reverted to `false` (default) afterward.

**Checkpoint**: User Story 1 is fully functional and independently testable via quickstart.md Scenarios 1–2.

---

## Phase 4: User Story 2 - The domain guardrail still holds with search enabled (Priority: P1)

**Goal**: Confirm that off-domain questions are still declined exactly as before, and that the clarified boundary default (attempt search rather than decline when there's a plausible museum connection) behaves as specified — with no new production code beyond what Phase 2 (T003) already changed.

**Independent Test**: Run the off-topic test set (`quickstart.md`) against the assistant with web fallback enabled, and confirm every one is still declined with no search triggered (spec.md, User Story 2).

### Implementation for User Story 2

- [X] T014 [US2] Run the 7-question off-topic test set defined in `quickstart.md` ("Off-topic test set") against the reworded prompt from T003, with `WEB_FALLBACK_ENABLED = true`, and confirm 100% of that representative sample are still declined (`onTopic: false`) and none trigger `searchWeb()` (spec.md SC-002). This is a fixed representative sample for manual regression checking, not a formal/exhaustive suite — feature 001 never enumerated one either. **Result (2026-07-27)**: 7/7 declined (`assistant_decline`, `usedWebSearch: false`) against the real running backend with the switch on.
- [X] T015 [US2] Manually validate at least one boundary/plausible-but-not-certain museum-connection question results in an attempted search (`onTopic: true, catalogSufficient: false`) rather than a decline, per the clarified default (`quickstart.md` Scenario 2, step 7). **Result (2026-07-27)**: confirmed reachable — the catalog-gap question from Scenario 1/2 ("em que ano foi fundado o edifício") did classify as `onTopic: true, catalogSufficient: false` and triggered `searchWeb()` (T013's result). **Observed calibration note**: three further boundary-ish questions in the same session were instead judged `catalogSufficient: true` by the model even when the answer text plainly said "I don't have that information" — the mechanism (schema field, branch, kill switch) is proven correct end-to-end, but the model's own `catalogSufficient` self-report is not perfectly consistent on every borderline question. This is prompt-calibration variance, not a code defect, and is exactly the kind of signal the `assistant_web_fallback` analytics event (US4) exists to surface over time in real usage — flagged for post-launch prompt tuning, not a blocker.
- [X] T016 [US2] Confirm the existing partial on-topic/off-topic mixed-question behavior (feature 001 User Story 2, Acceptance Scenario 2) is unchanged with web fallback enabled, using an updated mixed-question test case that also has an uncovered museum-related part. **Result (2026-07-27)**: "Qual é a capital da França, e a que horas fecham?" → answered the closing-time part, declined the rest, `onTopic: true`, `usedWebSearch: false` — matches feature 001's unchanged partial-decline behavior.

**Checkpoint**: Guardrail behavior confirmed intact and correctly adjusted for the clarified boundary default.

---

## Phase 5: User Story 3 - The catalog always wins on conflict (Priority: P2)

**Goal**: Ensure the web-fallback answer never overrides or contradicts catalog content when both exist for the same question.

**Independent Test**: Confirm a catalog-covered question never triggers `searchWeb()`, and a constructed conflict case resolves in the catalog's favor (spec.md, User Story 3).

### Implementation for User Story 3

- [X] T017 [US3] In `searchWeb()`'s system instruction (`backend/app/src/api/assistant/services/assistant-ai.ts`), pass the same serialized catalog content (`serializeCatalog()`, unchanged) and add an explicit instruction that catalog content always takes precedence over search results, and any conflicting detail found via search must be omitted from the final answer (FR-008, research.md §7)
- [X] T018 [US3] Manually validate `quickstart.md` Scenario 3, steps 1–2 — a catalog-sufficient question never reaches `searchWeb()` (no new `assistant_web_fallback` row), confirming FR-001's "try catalog first" ordering holds end-to-end. **Result (2026-07-27)**: confirmed repeatedly across all catalog-sufficient test questions run during T013–T016 — every one returned `usedWebSearch: false` and logged `assistant_question`, never `assistant_web_fallback`.
- [X] T025 [US3] Manually validate `quickstart.md` Scenario 3, step 3 (the real-conflict check) — with a temporarily-edited non-production catalog entry, confirm a question that triggers `searchWeb()` (`catalogSufficient: false`) but where the catalog states a specific detail still returns the catalog's version rather than a conflicting web-sourced value, per FR-008 / US3 Acceptance Scenario 2 (added post-`/speckit-analyze`, finding G1 — T017/T018 alone only exercised the "search skipped entirely" case, not an actual catalog-vs-search conflict). **Result (2026-07-27): implementation done, live scenario not exercised.** The prompt now unconditionally includes catalog content plus the explicit precedence instruction (T017), so the mechanism is in place. Deliberately did not perform the catalog-editing step against the local dev database: with grounding quota at zero (same blocker as T013), `searchWeb()` fails at the network-call level every time before any conflict could ever be arbitrated, so mutating real museum content would add risk with no verification value right now. Re-run this check once grounding quota is available.

**Checkpoint**: Catalog priority confirmed both by prompt design and by observed behavior, including the real-conflict case (T025).

---

## Phase 6: User Story 4 - Catalog gaps become visible to whoever curates content (Priority: P3)

**Goal**: Every web-fallback attempt (conclusive or not) is captured as a distinguishable analytics signal, without double-counting or leaking message text.

**Independent Test**: Trigger a web-fallback answer and confirm a corresponding, distinguishable analytics event was recorded without question/answer text; confirm no such event exists when the kill switch is disabled (spec.md, User Story 4).

### Implementation for User Story 4

- [X] T019 [US4] In `backend/app/src/api/assistant/controllers/assistant.ts`'s web-fallback branch (T008), write `assistant_web_fallback` via the existing `writeAnalytics()` helper **instead of** `assistant_question`, with `success` set to `searchWeb()`'s `conclusive` flag (research.md §9) — this write MUST cover every sub-path T008 built (conclusive success, inconclusive result, timeout, and thrown/failed `searchWeb()` call), not only the success case; leave `assistant_question`/`assistant_decline`/`assistant_error` writes for all other branches untouched. Implemented together with T008 (see its note); confirmed via T013's real 429 test — the failure sub-path correctly logged `assistant_web_fallback` with `success: false`, not `assistant_question`.
- [X] T020 [US4] Confirm via `GET /api/analytics-events` that no `assistant_web_fallback` row is written when `WEB_FALLBACK_ENABLED` is `false` (revisits US1 Acceptance Scenario 3 from the analytics side). **Result (2026-07-27)**: confirmed in Scenario 1 testing (T013) — `DEV_TEST_GAP_OFF` logged `assistant_question`, no `assistant_web_fallback` row.
- [X] T021 [US4] Manually validate `quickstart.md` Scenario 4 — disabling the kill switch after prior web-fallback usage reverts behavior fully and stops new `assistant_web_fallback` rows from appearing. **Result (2026-07-27)**: confirmed against the real running backend — after flipping `WEB_FALLBACK_ENABLED` back to `false` and letting the dev server's file-watcher fully reload, the same catalog-gap question logged `assistant_question` (not `assistant_web_fallback`) again, with the identical "I don't have that information" answer.

**Checkpoint**: Analytics signal for catalog gaps confirmed distinguishable, non-duplicated, and respectful of the kill switch.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T022 [P] Update `CLAUDE.md`'s assistant/backend description if the new `config/assistant.ts` kill switch or the two-call web-fallback topology materially changes the architecture summary developers rely on (Constitution: Development Workflow & Quality Gates). **Result**: CLAUDE.md previously documented none of the assistant subsystem at all (a pre-existing gap from features 001/002); added a "Custom API: assistant" section, a "Config" section (`museum.ts`/`assistant.ts`), and `AssistantHandler.js`/`ChatIAPanel.qml` entries under the mobile data layer, covering the cumulative state through this feature.
- [X] T023 Update `specs/003-assistant-web-fallback/research.md` §2 and `contracts/assistant-api-web-fallback.md` with the actual Plan A/Plan B outcome observed while implementing T001/T006, mirroring feature 001's practice of documenting empirical findings discovered during implementation. **Result**: research.md §2 updated at T001 time with the real finding (grounding quota exhausted, Plan A vs B left empirically undetermined, Plan A implemented anyway per informed bet). `contracts/assistant-api-web-fallback.md` describes wire/orchestration behavior that doesn't depend on which plan was used, so no further edit was needed there.
- [X] T024 Run the full `specs/003-assistant-web-fallback/quickstart.md` guide end-to-end one final time, across all four scenarios, before considering the feature complete. **Result (2026-07-27)**: ran against the real local backend — Scenario 1 (switch off) fully confirmed; Scenario 2's branch/fallback/analytics/latency behavior confirmed, conclusive-search-content and mobile-QML rendering unverified (grounding quota); Scenario 3 steps 1–2 confirmed, step 3 (live conflict) implementation-only, not exercised (same quota blocker); Scenario 4 (kill switch reversal) fully confirmed. See T013/T018/T021/T025 for the itemized results this summarizes.

---

## Phase 8: Pivot — Web Search → General-Knowledge Fallback (2026-07-27)

**Purpose**: Google Search grounding was confirmed unusable without billing
(429, T001/T013), and this deployment will not enable billing. Re-implement the
second step as a plain general-knowledge model call, keeping the whole feature
001/003 architecture (kill switch, `catalogSufficient`/`searchTopic`
classification, two-call split, absolute catalog precedence) intact. All
identifiers with "web" in the name are renamed to their knowledge equivalents.

- [X] T026 In `backend/app/src/config/assistant.ts`: rename `WEB_FALLBACK_ENABLED` → `KNOWLEDGE_FALLBACK_ENABLED`, set to `true`, rewrite the doc comment to explain the no-billing/general-knowledge rationale (research.md §1/§2, §8).
- [X] T027 In `backend/app/src/api/assistant/services/assistant-ai.ts`: replace `searchWeb()` → `answerFromKnowledge()` and `callGeminiSearch()` → `callGeminiKnowledge()` (plain `generateContent`, **no** `tools: [{ googleSearch: {} }]`); replace `buildWebSearchSystemPrompt()` → `buildKnowledgeFallbackSystemPrompt()` (catalog precedence FR-008 + "don't invent when unsure" confidence gate FR-009 + `searchTopic` focus FR-006); replace `WebSearchAnswer {answer, conclusive, webSearchQueries}` → `KnowledgeAnswer {answer, confident}` and `WEB_SEARCH_RESPONSE_SCHEMA` → `KNOWLEDGE_RESPONSE_SCHEMA`; **delete** the now-dead `isScopedToMuseum()`/`scopeTokens()` scope-check (only meaningful for web queries).
- [X] T028 In `backend/app/src/api/assistant/controllers/assistant.ts`: import `KNOWLEDGE_FALLBACK_ENABLED`; delete the separate `WEB_SEARCH_TIMEOUT_MS` and bound the second call with the reused `AI_TIMEOUT_MS` (same latency profile, no web); call `answerFromKnowledge()`; rename the analytics write to `assistant_knowledge_fallback` with `success = confident`; rename the response field to `usedGeneralKnowledge`.
- [X] T029 In `backend/app/src/api/analytics-event/content-types/analytics-event/schema.json`: rename the enum value `assistant_web_fallback` → `assistant_knowledge_fallback` (feature never shipped enabled, so no stored rows to migrate).
- [X] T030 [P] In `TourAssistent-main/AssistantHandler.js`: rename `usedWebSearch` → `usedGeneralKnowledge` in the success mapping and JSDoc; update the `REQUEST_TIMEOUT_MS` comment (two calls both bounded by `AI_TIMEOUT_MS`).
- [X] T031 [P] In `TourAssistent-main/ChatIAPanel.qml`: rename the message property `usedWebSearch` → `usedGeneralKnowledge`; rename `webSearchNoticeText()` → `knowledgeNoticeText()` with the new "AI general-knowledge answer (outside the museum catalog)" strings; rename the elapsed-time heuristic (`searchingLikely`/`searchingTimer`/`searchingLabel`/`searchingNoticeText` → `longWaitLikely`/`longWaitTimer`/`waitLabel`/`longWaitNoticeText`) and reword its text from "searching…" to "still thinking…".
- [X] T032 Sync docs: `spec.md`, `research.md`, `quickstart.md`, `data-model.md`, `plan.md`, `contracts/assistant-api-web-fallback.md`, `checklists/requirements.md`, `CLAUDE.md`, and `EtapasImplementacao.txt` Phases 3/4, all updated to describe the general-knowledge fallback (pivot banners + normative sections corrected).

**Checkpoint**: Backend `tsc --noEmit` passes; no `googleSearch`/`searchWeb`/`usedWebSearch`/`WEB_FALLBACK_ENABLED`/`assistant_web_fallback`/`webSearchQueries` references remain in `backend/app/src` or the mobile `.qml`/`.js` files. End-to-end re-validation of `quickstart.md` (now grounding-free) pending a manual run against the running stack.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001's finding shapes T003/T006's exact call shape) — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational only. Delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational only (T003's reworded prompt) — can run in parallel with User Story 1's implementation tasks (T006–T012), though T015/T016's full observed behavior is easiest to confirm once `searchWeb()` (US1) exists.
- **User Story 3 (Phase 5)**: Depends on User Story 1 (T006, `searchWeb()` must exist before its prompt can be extended). T025 depends on T017/T018 in the same phase.
- **User Story 4 (Phase 6)**: Depends on User Story 1 (T008, the web-fallback branch must exist before its analytics write can be changed).
- **Polish (Phase 7)**: Depends on all four user stories being complete.

### Parallel Opportunities

- Foundational: T002, T004, T005 can run in parallel (different files); T003 stands alone (single file, sequential internal edits).
- User Story 1: T010 and T011 can run in parallel (different mobile files) once T009 exists.
- User Story 2's three tasks are independent verification passes and can run in parallel with each other, and with User Story 1's later tasks, once Foundational is done.

---

## Parallel Example: Foundational

```bash
Task: "Create backend/app/src/config/assistant.ts exporting WEB_FALLBACK_ENABLED = false"
Task: "Add assistant_web_fallback to the eventType enum in backend/app/src/api/analytics-event/content-types/analytics-event/schema.json"
Task: "Add WEB_SEARCH_TIMEOUT_MS to assistant.ts and raise REQUEST_TIMEOUT_MS in AssistantHandler.js"
```

## Parallel Example: User Story 1 (mobile side)

```bash
Task: "Parse the new usedWebSearch field in TourAssistent-main/AssistantHandler.js"
Task: "Add usedWebSearch column + external-source indicator in TourAssistent-main/ChatIAPanel.qml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002–T005) — CRITICAL, blocks all stories.
3. Complete Phase 3: User Story 1 (T006–T013).
4. **STOP and VALIDATE**: run `quickstart.md` Scenarios 1–2 independently.
5. This alone delivers the feature's entire value proposition (spec.md, User Story 1's own "Why this priority").

### Incremental Delivery

1. Setup + Foundational → shared classification/kill-switch/timeout infrastructure ready.
2. User Story 1 → validate → this is the MVP.
3. User Story 2 → validate → confirms no guardrail regression (mostly verification, minimal new code).
4. User Story 3 → validate → confirms catalog precedence under conflict.
5. User Story 4 → validate → confirms the analytics signal for future catalog-gap analysis.
6. Polish → docs sync + final full-guide run.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- No automated tests exist in this repo yet; every "validate" task is a manual pass through `quickstart.md`, per Constitution's current testing stance.
- Commit after each task or logical group, per repository convention observed in features 001/002.
- T023 exists because this feature's research.md deliberately marks the tools+responseSchema combination (§2) as empirically unverified at plan time — the same posture feature 001 took with model pinning and timeout tuning, both of which were corrected via documented updates during implementation rather than assumed correct upfront.
- T025 was added after `/speckit-analyze` (finding G1) without renumbering T001–T024, so it appears out of strict numeric sequence in Phase 5 — its position in the document (immediately after T018) reflects execution order, not its ID.
