# Quickstart: Assistant General-Knowledge Fallback

Manual end-to-end validation (neither stack has an automated test suite yet, per the
Constitution's Development Workflow & Quality Gates — same as features 001/002).

> **Pivot note (2026-07-27):** the second step is a **general-knowledge** call
> (plain model call, no web search / grounding), not a Google search — see
> `research.md §1/§2`. Below, "external-source" / "search" indicators refer to the
> **"AI general-knowledge answer (outside the museum catalog)"** indicator, and
> the typing indicator switches to **"still thinking…"**, not "searching…".

## Prerequisites

- Backend running locally (`npm run develop` in `backend/app/`), with `GEMINI_API_KEY` set (same
  requirement as feature 001).
- The active museum entity (`ACTIVE_ENTITY_DOCUMENT_ID`, feature 002) configured and reachable.
- Mobile app built and running against the local backend (Desktop build is fastest for iteration).
- `KNOWLEDGE_FALLBACK_ENABLED` (`backend/app/src/config/assistant.ts`) — test both `false` and
  `true` (shipped default) states, per the scenarios below.

## Off-topic test set (used in Scenario 1, Scenario 2, and tasks.md T014)

Feature 001's own quickstart.md only ever demonstrates one off-topic example and one mixed example —
it does not enumerate a fixed set. To make this feature's "100% still declined" checks (SC-002)
concrete and repeatable rather than ad hoc, use this fixed set of 7 representative questions
whenever a task or scenario below says "the off-topic test set":

1. "What's the weather like today?"
2. "What's your favorite pizza topping?"
3. "Can you help me write a Python script?"
4. "Who won the last World Cup?"
5. "What's the capital of France?"
6. "Tell me a joke — anything, doesn't need to be about the museum."
7. "Can you recommend a good horror movie?"

Plus one mixed (partly on-topic) question, kept separate from the set above since it exercises
different behavior (partial decline, not a full decline):

- "What's the capital of France, and what time do you close?"

This is a representative sample for manual regression checking, not a formal/exhaustive test suite —
neither stack has automated tests yet (Constitution's Development Workflow & Quality Gates).

## Scenario 1 — Fallback disabled (no regression check)

1. Set `KNOWLEDGE_FALLBACK_ENABLED = false` (the shipped default is `true`). Restart the backend if you just changed it.
2. Open the assistant and ask a question that is clearly about the museum but that you know is
   **not** covered by the catalog (e.g., a historical detail about the building not present in any
   Area/Item description).
3. **Expected**: the assistant replies with its existing "I don't have that information" message —
   identical to feature 001's behavior before this feature existed. No general-knowledge indicator
   appears. No `assistant_knowledge_fallback` analytics-event row is created (check via the Strapi admin
   or `GET /api/analytics-events`).
4. Ask a clearly off-topic question from the off-topic test set above.
5. **Expected**: declined exactly as feature 001's User Story 2 already validates — unaffected by
   this feature regardless of the switch's state.

## Scenario 2 — Fallback enabled, museum-related question not in the catalog

1. Confirm `KNOWLEDGE_FALLBACK_ENABLED = true` (shipped default) and restart the backend.
2. Ask the same not-in-catalog museum question from Scenario 1, step 2.
3. **Expected**:
   - A relevant answer arrives within roughly 20 seconds (SC-001).
   - The chat panel's typing indicator switches to a distinguishable "still thinking…" state if the
     wait exceeds the usual catalog-only latency (roughly 8s+).
   - The returned message displays a visible "AI general-knowledge answer (outside the museum
     catalog)" indicator (separate from, and possibly alongside, the existing "Automatic translation"
     indicator if translation also applied).
   - A new `assistant_knowledge_fallback` analytics-event row exists with `success: true`, `language`
     matching the active language, and no message/answer text in its fields.
4. Ask a question the catalog *does* cover (e.g., an existing Item's description).
5. **Expected**: answered instantly from the catalog as before — no general-knowledge indicator, no
   `assistant_knowledge_fallback` event, `usedGeneralKnowledge` absent/false in the raw response (inspect via
   browser devtools / a manual `curl`/Postman call to `/api/assistant/ask` if you want to see the
   raw JSON).
6. Ask each question in the off-topic test set above (or at minimum the same one used in Scenario 1,
   step 4).
7. **Expected**: still declined, still no fallback triggered, for every question in the set — confirms User Story 2's guardrail
   holds even with the switch on. Ask a boundary-ish question with only a loose/plausible museum
   connection (e.g., something about the general historical period the museum covers, not a fact
   the catalog states) and confirm the assistant *attempts* a general-knowledge answer rather than declining
   outright, per the clarified default (spec.md Clarifications).

## Scenario 3 — Catalog priority on conflict

1. With `KNOWLEDGE_FALLBACK_ENABLED = true`, pick a question where the catalog already has a specific,
   correct answer (from Scenario 2, step 4).
2. **Expected**: still answered purely from the catalog — confirm no fallback was attempted at
   all for this question (FR-001, US3 AC1) by checking no new `assistant_knowledge_fallback` row appears.
3. **Real conflict check (FR-008, US3 Acceptance Scenario 2)**: steps 1–2 only prove the fallback is
   skipped when the catalog is already sufficient — they don't exercise the rarer case where the
   catalog states *something* but the model still judges it incomplete (`catalogSufficient: false`),
   triggering a fallback whose general knowledge could genuinely conflict with the catalog's own fact.
   To exercise that case:
   a. In a non-production Strapi environment (never the live/shared instance), temporarily edit one
      Item or Area's description so it states a specific, checkable detail (a date, a number, a
      name) that differs from what the model's general knowledge on that same topic would say.
   b. Ask the assistant a question broad enough about that Item/Area that the model is likely to
      judge the catalog's short description as incomplete (`catalogSufficient: false`), so the
      fallback call runs.
   c. **Expected**: the final answer states the catalog's version of the detail, not a conflicting
      value from the model's own knowledge, and does not present both side-by-side as equally valid.
   d. Revert the temporary catalog edit afterward.
   e. Note: because this relies on the model actually holding a differing value, treat this as a
      best-effort manual check rather than a guaranteed repro — the load-bearing guarantee is that
      `answerFromKnowledge()`'s system instruction (T017) unconditionally includes the catalog content
      and the catalog-precedence instruction on every call, not that any single manual trial produces
      an observable conflict.

## Scenario 4 — Kill switch reverses cleanly

1. With `KNOWLEDGE_FALLBACK_ENABLED = true` and at least one prior fallback answer observed (Scenario
   2), flip it back to `false` and restart the backend.
2. Re-ask the same not-in-catalog museum question.
3. **Expected**: reverts fully to Scenario 1's behavior — "I don't have that information", no
   indicator, no new analytics event — confirming SC-006 (single-value operator control, no other
   change required).

## What "done" looks like

- All four scenarios behave as described above, including Scenario 3's real-conflict check.
- No regression in feature 001's existing behaviors (translation indicator, in-session history,
  network-vs-service error distinction, off-topic decline) under either switch state.
- `specs/003-assistant-web-fallback/contracts/assistant-api-web-fallback.md` accurately reflects
  the shipped general-knowledge fallback (plain model call, no grounding — research.md §1/§2).
