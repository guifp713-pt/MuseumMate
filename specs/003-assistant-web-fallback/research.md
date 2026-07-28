# Phase 0 Research: Assistant Fallback (Web Search → General Knowledge)

> **Pivot outcome (2026-07-27, supersedes §1–§4 as originally decided):** the
> web-search approach these sections research was **abandoned before shipping**.
> The T001 spike (§2 update below) found Google Search grounding returns
> `429 RESOURCE_EXHAUSTED` on this API key with *or* without a schema — grounding
> has **zero quota without an active billing account**, and this academic
> deployment deliberately will not enable billing. Rather than block the feature,
> the second step was re-implemented as a **general-knowledge fallback**: a plain
> `generateContent` call (no `tools`, no grounding) that lets the model answer
> from its own trained knowledge, with the catalog still passed in as the
> authoritative source and a strict "don't invent when unsure" instruction. This
> trades verifiable web provenance for zero-cost availability and accepts a
> hallucination risk, mitigated by catalog precedence (§7) and the confidence
> gate. The sections below are kept as-is for the historical rationale of what was
> tried; where they say "search"/"grounding", the shipped behavior is the plain
> knowledge call instead. §5 (classification), §6 (latency/indicator), §7 (catalog
> precedence), §8 (kill switch), §9 (analytics) and §10 (response contract) still
> apply, with the names updated (`answerFromKnowledge`, `KNOWLEDGE_FALLBACK_ENABLED`,
> `assistant_knowledge_fallback`, `usedGeneralKnowledge`).

## 1. Web search mechanism & provider

**Decision**: Reuse the existing Gemini call from feature 001 — same model (`gemini-3.1-flash-lite`, already pinned in `assistant-ai.ts`), same `@google/genai` SDK (`^2.12.0`, already a dependency), adding Gemini's built-in **Google Search grounding tool** (`tools: [{ googleSearch: {} }]`) rather than integrating a separate third-party search API.

**Rationale**: No new dependency, no new provider credential, no new deployable — the backend already calls this exact model server-side (Constitution Principle III, YAGNI). `gemini-3.1-flash-lite` belongs to the Gemini 3.x generation, which is the generation Google ships native Search grounding for. Confirmed via the installed SDK's type declarations (`node_modules/@google/genai/dist/genai.d.ts`): `GoogleSearch` tool type, `GroundingMetadata` (with `webSearchQueries`, `groundingChunks`, etc.) all already ship in the installed SDK version — no upgrade needed.

**Alternatives considered**: A dedicated search API (e.g., a generic web-search REST provider) called directly from the backend (rejected: new dependency, new credential to manage, and duplicates a capability the already-integrated AI provider offers natively); client-side search (rejected: same key-exposure anti-pattern feature 001's Research §1 already rejected for the AI call itself).

## 2. Combining structured output with the search tool

**Decision**: Attempt a **single Gemini call** for the web-fallback step that combines `tools: [{ googleSearch: {} }]` with `responseMimeType: "application/json"` + `responseSchema` (same structured-output mechanism feature 001 already uses, Research §5 of `001-ai-museum-assistant`). Verify this empirically against the real API during implementation, exactly as feature 001's Research §2 (model pinning) and §7 (timeout tuning) were validated empirically rather than assumed. If the installed SDK/model pairing rejects the combination, fall back to a documented Plan B (below) without changing the feature's external behavior.

**Rationale**: A live web search confirms Gemini 3.x officially supports combining Structured Outputs with built-in tools including Google Search grounding in a single request — this was a real limitation on older Gemini generations (2.x) but has been lifted for Gemini 3, which is exactly the generation already pinned here. One caveat surfaced in the same search: some SDKs may not yet expose this combination even when the native API supports it, which is why this decision is marked for empirical verification rather than treated as settled — the same posture feature 001 took with model availability (its Research §2 update log documents two live-tested model swaps during implementation).

**Plan B (fallback, only if empirically needed)**: Drop `responseSchema` for the search call, keep `tools: [{ googleSearch: {} }]`, and instruct the model via the system prompt to reply in plain text, ending with a machine-checkable exact-match sentinel line (e.g. a literal `NO_RESULT` token, and nothing else) when it cannot find a reliable answer. The backend parses for that exact sentinel rather than JSON. This reintroduces a category of fragility feature 001's Research §5 explicitly avoided for translation provenance — it is accepted here only as a fallback, and only for this one call, because the alternative (a third round-trip purely to re-package a grounded free-text answer into structured JSON) would cost an extra network hop against an already-tight latency budget (§6 below) for no benefit beyond parsing convenience.

> **Update (2026-07-27, T001 spike, tasks.md)**: empirical verification against the real API was
> **inconclusive**, for a reason one level below the question this spike set out to answer. Three
> live calls were made against the project's actual `GEMINI_API_KEY` on `gemini-3.1-flash-lite`:
>
> - Plain call (no tools, no schema): `200 OK`.
> - `responseSchema` only (no tools): `200 OK`.
> - `tools: [{ googleSearch: {} }]`, with **or without** `responseSchema`: both attempts returned
>   `429 RESOURCE_EXHAUSTED` ("You exceeded your current quota").
>
> In other words, **grounding itself has zero available quota on this API key right now** —
> identical failure with or without a schema attached, so this spike cannot actually distinguish
> "Plan A is unsupported" from "grounding is unreachable at all on this account." This is the same
> shape of surprise feature 001's Research §2 already hit once (the free tier being reorganized out
> from under a previously-working model) — evidently the same risk applies to grounding access, not
> just to model access.
>
> **Decision given this ambiguity**: implement `searchWeb()` per Plan A (combined `tools` +
> `responseSchema` in one call) anyway, since it remains the best-evidenced approach from public
> documentation (§2 above) and nothing observed here actively contradicts it — the 429 is a quota
> gate, not a `400`-style rejection of the request shape. This is a deliberate, informed bet, not a
> confirmed-working path: **the combined call is unverified end-to-end pending grounding
> quota/billing being available on a usable API key.** Re-run the T001 spike script's three calls
> once quota is available, and update this section with the real Plan A/B outcome before treating
> `searchWeb()` as validated (tasks.md T023 covers this follow-up).



**Alternatives considered**: Always doing a third "compose" call (schema-only, no tools) that takes the grounded free-text answer as input and reshapes it into JSON (rejected as the default path: adds a full extra round-trip to every web-fallback answer, directly working against SC-001's 20s target; kept only as a mental fallback-of-the-fallback if Plan B's sentinel parsing proves unreliable in practice).

## 3. Cost / quota viability (resolves NFR-3.2's open question)

**Decision**: Enable web fallback as viable at this museum's expected traffic scale, backed by the operator kill switch (FR-011) as the safety valve, rather than blocking the feature on cost uncertainty.

**Rationale**: As of the current pricing structure, the Gemini 3.x model family (which `gemini-3.1-flash-lite` belongs to) includes **5,000 free grounded (Google Search) prompts per month**, with paid overage at roughly $14 per 1,000 grounded queries beyond that. For a single museum's assistant — a niche, low-traffic use case compared to consumer-scale products — 5,000 free grounded questions per month is a generous ceiling relative to expected visitor volume, and only questions classified as "museum-related but not in the catalog" ever reach this call at all (FR-001/FR-003), not every assistant interaction. This directly answers the phase notes' open question (NFR-3.2): the free tier is viable for this version, not merely "possibly eligible."

**Alternatives considered**: Blocking this feature until a paid billing account is confirmed (rejected: the free quota is generous enough for this feature's realistic scale, and the kill switch already exists as the cost-control mechanism if usage ever approaches the ceiling — building additional cost-gating now would be speculative, Constitution Principle III).

## 4. Restricting the search "query" given native grounding

**Decision**: Because Gemini's built-in Google Search grounding tool does not accept a caller-supplied query string — the model decides what to search internally — FR-006's "restricted, system-built query" requirement is satisfied through two complementary mechanisms instead of literal query construction:

1. **Prompt-level scoping**: the web-fallback call's system instruction explicitly names the active museum and a short `searchTopic` phrase (see §5) and instructs the model to search only within that scope, never on the visitor's phrasing verbatim, and never for anything the catalog and museum domain don't cover.
2. **Post-hoc verification**: after the call returns, the backend inspects `response.candidates[0].groundingMetadata.webSearchQueries` (a `string[]` the SDK already exposes per its type declarations) and confirms at least one issued query is recognizably scoped to the museum (e.g., contains the museum's name). If not, the backend discards the result and treats the attempt as inconclusive (§ Controller orchestration in `data-model.md`) rather than surfacing an unscoped answer.

**Rationale**: This is the closest achievable equivalent to "system-built restricted query" given the chosen mechanism (§1) doesn't expose a raw query parameter — the alternative would be abandoning native grounding for a classic search-API integration purely to get manual query control, which reintroduces the new-dependency cost §1 already rejected. The post-hoc check is a real, code-level guardrail (not just a prompt instruction the model could ignore), which keeps FR-006 enforceable rather than aspirational.

**Alternatives considered**: Trusting the system-prompt instruction alone with no verification (rejected: prompt instructions are not a hard guarantee, and FR-006 is one of this feature's explicit safety requirements); switching to a search API that accepts a literal query string (rejected per §1).

## 5. Extending the on-topic/catalog classification (FR-002, FR-005)

**Decision**: Extend the existing single structured call (`assistant-ai.ts`'s `ask()`, unchanged in topology) with two additional response fields, rather than adding a separate classification call:

- `catalogSufficient: boolean` — true when the answer already produced is fully grounded in the catalog; false when the model had nothing relevant in the catalog for an on-topic question (the existing "I don't have that information" case, already produced today per feature 001's FR-012 prompt instruction).
- `searchTopic: string` — a short (roughly ≤8 words) restricted topic phrase, populated only when `onTopic && !catalogSufficient`, used to seed the web-fallback call's scoping instruction (§4). Empty string otherwise.

The existing `onTopic` field's underlying prompt definition is reworded slightly to reflect the clarified boundary default (spec Clarifications, session 2026-07-27): a question is off-topic only when it has **no plausible connection** to the museum, not merely when relatedness isn't "clearly" established — the opposite of the wording direction feature 001 used, but the qualifying/disqualifying test itself was already model-driven prompt instruction, not code, so this is a prompt-text edit, not an architecture change.

**Rationale**: Classification and the primary answer attempt are already one LLM call in feature 001 (Research §4); asking the same call to also flag catalog-sufficiency costs nothing extra (no added round trip) and keeps the "try catalog first" behavior (FR-001) intact — the model still always attempts the catalog-only answer first, and simply also reports whether that attempt was satisfying. Reusing structured output (rather than a second free-text classification call) avoids adding latency ahead of the search step, which matters most since the search step already adds its own latency (§6).

**Alternatives considered**: A dedicated pre-classification call before the main answer attempt (rejected: doubles latency/cost for every single message, not just the subset that needs web fallback — feature 001's Research §4 already rejected this shape for the same reason); keyword-based catalog-sufficiency detection instead of a model-reported flag (rejected: as fragile as regex-based topic filtering, which Research §4 of feature 001 also rejected).

## 6. Latency budget & the "searching…" indicator

**Decision**: 
- Add a second, independent server-side timeout for the web-fallback call (`WEB_SEARCH_TIMEOUT_MS`, proposed **20000ms**, reusing the existing `withTimeout` helper in `assistant.ts`), separate from and in addition to the existing `AI_TIMEOUT_MS` (20000ms) that already bounds the catalog-only call.
- Raise the mobile client's single request timeout (`AssistantHandler.js`'s `REQUEST_TIMEOUT_MS`, currently 25000ms) to a value that comfortably exceeds the worst-case **sum** of both server-side timeouts for a path that hits both calls (up to ~40s in the rare worst case where both individually time out) — proposed **45000ms**. This preserves the existing invariant from feature 001's Research §7 (server timeout(s) must lose the race against the client timeout so the backend can return a structured error and log analytics before the client gives up).
- The visible "searching…" indicator (spec Clarifications) is implemented **client-side only**, as a heuristic elapsed-time swap on the existing `ChatIAPanel.qml` typing indicator: once `waitingForReply` has been true for longer than the typical catalog-only answer latency (~8s, informed by feature 001's Research §7 measured range of 2.7–9.9s), the indicator's label switches from the current plain typing dots to a distinguishable "searching…" text. This requires no new signal from the server (no streaming/SSE), since the backend genuinely cannot tell the client "I'm now searching" mid-request under the existing single request/response topology.

**Rationale**: The two-call path (catalog attempt + web search) is strictly slower than the existing single-call path, and only reachable for the subset of questions classified as "museum-related but uncovered" — the common (a)/(c) paths are entirely unaffected and keep today's ~5-7s typical latency and 20s/25s timeout pair. A purely time-based client heuristic for the "searching…" label avoids a much larger architectural change (streaming intermediate state from the backend) for a UI nicety, consistent with Constitution Principle III.

**Alternatives considered**: Streaming the backend's progress (e.g., an SSE "now searching" event before the final answer) so the client's indicator reflects real server state (rejected: a materially larger change to the request/response contract for one UI indicator, when a latency-based heuristic already satisfies the clarified requirement — "whenever the wait is expected to exceed the catalog-only path's normal response time" is itself a heuristic framing, not a claim of exact server-state awareness).

## 7. Catalog-priority enforcement (FR-008)

**Decision**: The web-fallback call's system instruction includes the same serialized catalog content already built for the primary call (`serializeCatalog()`, unchanged, reused as-is) alongside an explicit instruction that catalog content always takes precedence over anything found via search, and that any conflicting detail from a search result must be omitted from the final answer. No separate reconciliation/arbitration call is introduced.

**Rationale**: The model already has full catalog context in the primary call; passing the same context into the search call lets the single model instance perform the "catalog wins" arbitration itself in the same call that produces the answer, at zero extra latency cost. A separate reconciliation step would be a third round-trip for a case (catalog and search directly conflicting on the same fact) that the Edge Cases section already notes is rare.

**Alternatives considered**: Running the search call catalog-blind and reconciling in a separate step (rejected: extra round-trip, and the search call already has everything it needs to self-arbitrate given the same catalog text the primary call uses).

## 8. Kill switch placement (FR-011)

**Decision**: A single new backend-only config constant, `WEB_FALLBACK_ENABLED`, in a new file `backend/app/src/config/assistant.ts`, defaulting to `false`. No mobile-side counterpart is needed — the mobile app never decides whether web fallback runs; it only ever renders whatever `usedWebSearch` flag the backend's response already carries.

**Rationale**: Unlike feature 002's `ACTIVE_ENTITY_DOCUMENT_ID` (which genuinely needs a value on both stacks because the mobile app makes its own direct Strapi content calls), this switch only gates server-side orchestration in `assistant.ts` — the mobile app has no code path that depends on knowing the switch's value in advance, so introducing a mirrored mobile constant would be pure duplication risk with no behavior it drives (would directly contradict Constitution Principle I's rationale, which exists to prevent exactly that kind of unnecessary duplicate value). A dedicated `config/assistant.ts` (rather than adding to `config/museum.ts`) keeps the single-responsibility split feature 002 already established: one file per configuration concern.

**Alternatives considered**: An environment variable instead of a source-level constant (rejected: no other configuration value in this codebase currently uses env-based feature flags for behavior toggles — `GEMINI_API_KEY` is the only env var, and it's a secret, not a feature flag; a plain exported constant matches the existing `ACTIVE_ENTITY_DOCUMENT_ID` precedent exactly, which is a one-line, git-diff-visible toggle that satisfies FR-011's "single, centrally-defined configuration switch" without introducing a new configuration mechanism).

## 9. Analytics event semantics (FR-010)

**Decision**: When a question reaches the web-fallback branch (`onTopic && !catalogSufficient` while the switch is enabled), the backend writes exactly one `assistant_web_fallback` analytics event **instead of** the `assistant_question` event that branch would otherwise have produced — not an additional event alongside it. `success` on that event reflects the search call's `conclusive` outcome (true = answered from search, false = search attempted but inconclusive, still falls back to "I don't have that information"). The existing `assistant_decline`/`assistant_error` events are untouched for the branches that don't reach web fallback at all.

**Rationale**: Matches the spec's User Story 4 framing ("an analytics event distinguishable from ordinary catalog answers is recorded" — singular), and avoids double-counting the same interaction under two different event types, which would inflate both metrics and make the eventual dashboard aggregation (a later phase, per the project's own phased roadmap) misleading.

**Alternatives considered**: Logging both `assistant_question` and `assistant_web_fallback` for the same interaction (rejected: double-counts one visitor interaction as two analytics rows, complicating any future "total questions answered" metric).

## 10. Response contract extension (NFR-3.4)

**Decision**: Add one new optional-in-practice boolean field, `usedWebSearch`, to the existing `AssistantAskResponse` (`{ answer, autoTranslated, onTopic }` → `{ answer, autoTranslated, onTopic, usedWebSearch }`). `AssistantHandler.js` already destructures named fields defensively (`data.autoTranslated === true`, `data.onTopic !== false`) rather than spreading the whole object, so an older client build simply never reads the new field — no breaking change either direction.

**Rationale**: Directly satisfies NFR-3.4 ("additive, no breaking the current client") using the exact same defensive-field-read pattern already established in `AssistantHandler.js` for the two existing boolean flags — no new normalization pattern is introduced (Constitution Principle II).

**Alternatives considered**: A nested `source: { type: "catalog" | "web", ... }` object (rejected: over-structures a single boolean for no present need — YAGNI; the flat boolean is symmetrical with the existing `autoTranslated` flag it sits beside).
