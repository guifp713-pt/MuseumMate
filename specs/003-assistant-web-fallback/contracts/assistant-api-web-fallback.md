# Contract Delta: Assistant Ask Endpoint (General-Knowledge Fallback)

> **Pivot note (2026-07-27):** this feature originally used Google Search
> grounding for the second step. Grounding requires an active billing account on
> the Gemini API key (every grounded call returns `429 RESOURCE_EXHAUSTED`
> without it), which this deployment deliberately avoids. The second step is now
> a **plain model call that answers from the model's own general knowledge**,
> with the catalog kept as the authoritative source. See `research.md §1/§2` for
> the full rationale. The endpoint, method, auth and request body are all
> unchanged; only the response gains one field and the orchestration gains a
> conditional second step.

## `POST /api/assistant/ask` — response body (extended)

### Success response — `200`

```json
{
  "answer": "The building itself dates to the early 20th century and was originally...",
  "autoTranslated": false,
  "onTopic": true,
  "usedGeneralKnowledge": true
}
```

| Field | Type | Notes |
|---|---|---|
| `answer` | string | Unchanged. |
| `autoTranslated` | boolean | Unchanged. |
| `onTopic` | boolean | Unchanged in shape. `false` still means an on-domain decline (FR-004/FR-012, feature 001) — this path is entirely unaffected by the fallback. |
| `usedGeneralKnowledge` | boolean | **New, additive.** `true` only when the final answer came from the general-knowledge fallback step (below) and the model reported itself confident. Absent/`false` for every other case, including catalog answers, declines, and non-confident fallback attempts (which still return the standard "I don't have that information" text). |

Error responses (`400`/`502`/`504`) are unchanged from feature 001's contract.

## Internal orchestration (not part of the wire contract, but load-bearing for FR-001–FR-013)

Extends feature 001's contract step list (`assistant-api.md`, "What the backend does on every call"):

1. Builds the system prompt from the current catalog (unchanged) and calls the model with an **extended** structured-output schema: `{ answer, autoTranslated, onTopic, catalogSufficient, searchTopic }` (see `data-model.md`, Question Classification).
2. If `onTopic` is `false`: responds exactly as feature 001 does today (decline). No further steps.
3. If `onTopic` is `true` and `catalogSufficient` is `true`: responds exactly as feature 001 does today (catalog answer). No further steps.
4. If `onTopic` is `true` and `catalogSufficient` is `false`:
   a. If `KNOWLEDGE_FALLBACK_ENABLED` (`backend/app/src/config/assistant.ts`) is `false`: responds with the same "I don't have that information" `answer` the first call already produced, `usedGeneralKnowledge: false`. Writes `assistant_question` analytics exactly as feature 001 does today — **no behavior change at all** versus a deployment without this feature.
   b. If `KNOWLEDGE_FALLBACK_ENABLED` is `true`: calls the new `assistant-ai.ts` function `answerFromKnowledge({ catalog, message, language, searchTopic })`, which invokes the model with a **plain** generateContent call (no tools, no grounding), the same serialized catalog content, and a system instruction that (i) focuses the answer on `searchTopic` in connection with the active museum, (ii) asserts catalog precedence over anything from the model's own knowledge (FR-008), and (iii) requires the model to set `confident: false` rather than fabricate when it is not sure (FR-009). It returns `{ answer, confident }`.
      - On a confident result: responds with `{ answer: <knowledge answer>, autoTranslated: false, onTopic: true, usedGeneralKnowledge: true }`. Writes one `assistant_knowledge_fallback` analytics event, `success: true`, **instead of** `assistant_question` for this interaction.
      - On a non-confident result, a thrown error, or the `AI_TIMEOUT_MS` timeout: responds with the same "I don't have that information" text from step 1's first call, `usedGeneralKnowledge: false`. Writes one `assistant_knowledge_fallback` analytics event, `success: false`.

5. Analytics writes (`writeAnalytics`, unchanged helper) never include `message`/`answer` text, per feature 001's existing FR-016 discipline — unaffected by this feature.

## Timeouts (extends feature 001's Research §7 / `assistant.ts`'s `AI_TIMEOUT_MS`)

| Constant | Location | Value | Notes |
|---|---|---|---|
| `AI_TIMEOUT_MS` | `assistant.ts` (existing) | 20000ms | Bounds **both** the primary/classification call and the general-knowledge fallback call — the fallback is a plain model call with the same latency profile, so no separate timeout is needed. |
| `REQUEST_TIMEOUT_MS` | `AssistantHandler.js` (existing, raised) | 25000ms → 45000ms | Must stay strictly greater than the worst-case **sum** of the two server calls that a request reaching step 4b makes (2×`AI_TIMEOUT_MS` ≈ 40s) — preserves the server-wins-the-race invariant from feature 001's Research §7. |

## What does NOT change

- Request body shape (`message`, `language`, `sessionId`, `history`) — identical to feature 001.
- Error status codes and bodies (`400`/`502`/`504`) — identical to feature 001.
- The mobile app's network-vs-service-error distinction (`xhr.onerror` vs. non-200) — identical to feature 001.
- Conversation history handling (in-memory only, FR-009/FR-014 of feature 001) — identical.
