# Phase 0 Research: AI Museum Assistant

## 1. AI provider & call topology

**Decision**: Google Gemini API, called **only from the Strapi backend** (a new custom `assistant` API), never directly from the mobile client.

**Rationale**: The mobile app is a distributed binary; embedding an AI provider API key in it is a hard security anti-pattern (extractable from the APK). The existing architecture already funnels all data access through Strapi (`ApiHandler.js` → Strapi REST), so adding one more server-mediated endpoint is consistent with that boundary and with Constitution Principle II (single normalization boundary). Clarification session confirmed no data-residency constraint restricts provider choice.

**Alternatives considered**: Direct client→AI-provider calls (rejected: key exposure); a third microservice dedicated to AI (rejected: YAGNI for one endpoint, adds an extra deployable to a two-stack constitution).

## 2. Model selection

**Decision**: `gemini-3.1-flash-lite`, hardcoded — no environment-variable override to a higher tier (e.g. Gemini Pro) in this version.

> **Update (2026-07-20, during implementation)**: this decision originally named
> `gemini-2.0-flash-lite`. The Flash-Lite *tier* choice and the "pin the model,
> no env-var override" rule below both remain valid — only the concrete model
> version changed, for the following reason.
>
> The free tier was reorganized by Google in December 2025 and the 2.0 Flash-Lite
> generation no longer has free quota allocated to it. This was confirmed
> empirically against the project's own API key during implementation:
>
> - `gemini-2.0-flash-lite` → `429 RESOURCE_EXHAUSTED`, explicitly
>   `limit: 0` on `generate_content_free_tier_requests` (the model still exists
>   and authenticates — it simply has no free-tier allowance).
> - `gemini-2.5-flash-lite` → `404 NOT_FOUND`, *"no longer available to new users"*.
>   The 2.5 generation is therefore not a viable replacement either.
> - `gemini-3.1-flash-lite` → `200 OK`. This is the current Flash-Lite generation
>   available on the free tier, and is what the implementation now pins.
>
> The alias `gemini-flash-lite-latest` also works, but was deliberately **not**
> chosen: an alias silently re-points to a different model over time, which
> would defeat the "intentionally fixed value" rationale below. A concrete
> pinned version keeps the model change an explicit, reviewed edit.
>
> Note this is a moving target — model availability shifted twice within this
> feature's own implementation window, so a future version may need to re-pin
> again. The `404`/`429` responses above are the diagnostic signal to look for.

**Rationale**: Google Gemini's free tier covers this version's ~20-question functional test at zero cost on the current Flash-Lite generation. This feature's task — grounding answers in a small (~30 item/~10 area) catalog with a fixed structured output shape and a simple on-topic/off-topic instruction — does not require Gemini Pro-tier capability. For this version's goal (an initial functional test of ~20 questions, not a production rollout), Flash-Lite is both sufficient for the task and free at this volume, so there is no scenario in this version where trading up to a costlier tier is desired. Verified in practice: the implementation returns correct, catalog-grounded answers in all four languages on this model. The model is intentionally hardcoded rather than exposed via an environment variable to remove any path — accidental config change, copy-pasted `.env`, etc. — by which a costlier tier could be selected in this version.

**Alternatives considered**: Gemini Pro tier (rejected: no free-tier equivalent at this generosity, and no corresponding capability need for this closed, small-catalog task — contradicts this version's goal of a zero-cost functional test). Env-var-configurable model tier (rejected for this version: since no scenario currently calls for a different tier, an override only adds a way to accidentally incur higher cost; this can be reintroduced in a later version if a real need to change tiers arises — see Constitution Principle I, which calls for externalizing values that legitimately vary by deployment, not values that are intentionally fixed).

## 3. Catalog retrieval strategy

**Decision**: On each request, the backend fetches the full localized catalog for the visitor's active language (entities, areas, items, tours, dictionary — reusing the same populate shape `ApiHandler.js` already queries) and serializes it into the system prompt as plain structured text. Response is cached in-process per language for a short TTL (5 minutes) to avoid re-querying the DB on every message in a burst of conversation turns.

**Rationale**: The spec's own assumption calls this out explicitly: catalog is small (~30 items, ~10 areas) and "a significant catalog growth may require revisiting the retrieval approach in a future version." At this scale, the full catalog comfortably fits in any current Gemini model's context window, and full-catalog visibility is *required* anyway by FR-002 (assistant must answer about the whole museum, not just the current screen) — so there is nothing a retrieval/ranking step would usefully filter out.

**Alternatives considered**: Vector search / embeddings-based RAG (rejected: YAGNI per Constitution Principle III at this scale, and adds a new storage dependency and indexing pipeline for no measurable benefit); on-device filtering to "relevant" catalog subset before sending (rejected: defeats FR-002's requirement that the assistant reason over the entire catalog, and duplicates population logic already in `ApiHandler.js`).

## 4. Off-topic refusal mechanism

**Decision**: A single system-prompt instruction defining the museum domain (per the spec's Assumptions bullet) and declining out-of-domain questions, enforced through the model's own instruction-following — no separate classifier call.

**Rationale**: This matches the original feature request ("recusar perguntas fora do domínio através de uma instrução de sistema simples") and keeps the assistant to one LLM call per message, which matters for the SC-001 10-second budget. A second classification round-trip would double latency and cost for no measurable reliability gain at this scale.

**Alternatives considered**: Pre-classification call before the main answer (rejected: doubles latency/cost); keyword/regex-based topic filter (rejected: too brittle for natural-language museum questions, and duplicates what the LLM already does well).

## 5. Structured response format (translation provenance + on-topic classification)

**Decision**: Use the Gemini API's structured output support (`responseMimeType: "application/json"` combined with a `responseSchema` on the generation config, as exposed by the `@google/genai` SDK) so every assistant call returns `{ answer: string, autoTranslated: boolean, onTopic: boolean }` in one guaranteed-parseable response, rather than free text plus a regex-parsed marker.

**Rationale**: FR-005/FR-006 need the backend to know, per answer, whether official catalog text or an AI translation was used (to drive FR-015's UI indicator); FR-016 needs to classify each interaction as a question/decline/error for analytics. Structured outputs give both flags from the same single call that produces the answer, so no extra round trip is needed and there's no fragile text-marker parsing to get wrong.

**Alternatives considered**: Free text plus an appended machine-readable footer parsed via regex (rejected: fragile — a stray delimiter in the answer text would break parsing); a second "was this translated?" call (rejected: doubles latency/cost per message, harming SC-001).

## 6. Rate limiting

**Decision**: No rate limiting implemented in this version.

**Rationale**: The clarification session resolved that any internal rate limit must be invisible and must never block or delay a message. The simplest implementation that trivially satisfies "never blocks" is to not implement one yet — nothing to violate. This can be revisited if usage data shows the AI provider's quota is actually at risk (Constitution Principle III: don't build for a hypothetical need).

**Alternatives considered**: An in-memory sliding-window counter that only logs a warning past a threshold (rejected for v1: no observed need yet, adds code with no behavior change since it still can't block — pure YAGNI until real usage data exists).

## 7. Connectivity / failure handling

**Decision**: The new mobile-side `AssistantHandler.js` reuses the existing `XMLHttpRequest` `onerror`/status-check pattern already used by `AnalyticsHandler.js` and `ApiHandler.js`. Two distinct mechanisms cover the two distinct edge cases the spec calls out separately:

- **SC-006 (no internet connection, 5s budget)** is satisfied by `xhr.onerror`, which fires as soon as the OS reports no route to host — independent of, and not bounded by, any configured request timeout. This is what maps to the "needs an internet connection" message (FR-008).
- **"AI/translation service unavailable while connectivity is fine"** (an Edge Case in spec.md, with no numbered Success Criterion of its own) is bounded by an explicit client-side request timeout (~13s — see the update note below), so a hung request still surfaces the "service unavailable" message in a reasonable time even though nothing in spec.md sets a hard budget for this specific case. A timeout or non-2xx backend response maps to this "service unavailable" message.

The backend's own call to the Gemini API is bounded by an explicit **~20s server-side timeout**, deliberately shorter than the client's **~25s** timeout. The Strapi `assistant` controller races the `@google/genai` call against this timeout and, if it fires first, returns `504 { "error": "assistant_unavailable" }` (see `contracts/assistant-api.md`).

> **Update (2026-07-20, during implementation)**: these values were originally
> **6s server / 8s client**. Measured end-to-end latency against the real Gemini
> API came in at **~5.4s (PT) to ~6.0s (EN)** — close enough to the original 6s
> server timeout that normal, successful answers risked being aborted as
> spurious `504`s. The server timeout was therefore raised to **10s**.
>
> The client timeout was raised to **13s** *in the same change*, and this pairing
> is load-bearing: the invariant below is that the server timeout must be
> strictly less than the client's. Raising the server to 10s while leaving the
> client at 8s would have inverted that relationship and produced exactly the
> failure this section's rationale rejects — the client giving up first, the
> visitor getting a generic network error instead of the structured
> service-unavailable message, and the backend never writing its
> `assistant_error` row.
>
> Note the interaction with **SC-001 (answers within 10 seconds)**: a 10s server
> timeout is now the ceiling for a *successful* answer, so a response that only
> resolves at ~9.9s would satisfy the timeout but breach SC-001 once network
> overhead is added. Observed latency (~5-6s) leaves comfortable headroom, but if
> real-world latency creeps up, SC-001 — not the timeout — is the constraint that
> binds first.
>
> **SC-006 is unaffected** by both values: the "no internet" case is detected by
> `xhr.onerror`, which fires on the OS's no-route-to-host signal independently of
> any configured timeout (as the bullet above already explains).

> **Update (2026-07-21, Phase 6 validation)**: raised again to **20s server /
> 25s client** after two consecutive `504`s in runtime testing. The paragraph
> above predicted the wrong cause: latency did not "creep up" uniformly — it is
> *dispersed*.
>
> Evidence (same question, same prompt, same 192-char answer, 4 consecutive
> runs): **6.5s, 7.3s, 7.5s, 9.3s**. Across the wider sample the range was
> 2.7s–9.9s, and a **897-char** answer returned in **4.9s** — faster than a
> 192-char one. Neither input size nor output size predicts the latency; the
> tail is provider-side variance.
>
> This is why the alternative of **shrinking the catalog prompt was rejected**:
> the whole serialized PT catalog is only ~2-3K tokens (1 entity, 2 tours, 7
> areas, 11 items, 33 dictionary entries — ~22K chars of *raw JSON including
> metadata the prompt never carries*). Halving it would save a sub-second slice
> of input processing against a ~3s dispersion, while costing FR-002's
> whole-catalog reasoning — the same trade §3 already rejected.
>
> **SC-001 is now the binding constraint, and it is knowingly exceeded in the
> tail.** A 20s ceiling means a slow answer arrives late rather than not at all;
> at 10s the tail became hard `504`s, which is strictly worse for the visitor.
> SC-001 should be re-read as a target for typical latency (median ~5-7s here),
> not as the timeout value. **Open follow-up**: with a ceiling this high, the
> chat panel needs a visible pending indicator — `ChatIAPanel.qml` tracks
> `waitingForReply` but renders nothing for it, so a tail-latency request looks
> like a frozen UI for ~10s.

**Rationale**: Reuses an established, working pattern in this codebase instead of introducing a new one (Constitution Principle III). Splitting the failure handling into two mechanisms matters because the two edge cases have different (or absent) time budgets: SC-006's 5s target could not be met by an 8s client timeout if the "no internet" case depended on that timeout — it doesn't, because `xhr.onerror` fires immediately and well within 5s on its own, with no dependency on the 8s/6s values. The 8s/6s timeouts exist solely to bound the separate, unbudgeted "service unavailable" case. Within that pair, the server-side timeout must be strictly less than the client-side timeout so the backend "wins the race": it gets to return the structured `504` (and write the `assistant_error` analytics row) before the client's own timeout would otherwise fire and abandon the request with only a generic network-level failure. If the two were equal or the server timeout were longer, the client could time out first, leaving the visitor with a less specific error and the backend with an analytics gap.

**Alternatives considered**: A dedicated network-reachability check before sending (rejected: redundant with `onerror`, which already fires promptly on no-route conditions in this app's existing code). A server-side timeout equal to or greater than the client's (rejected: risks the client giving up first, defeating the purpose of a structured `504` response — this is the invariant, independent of the concrete values, which have since moved to 20s/25s).

## 8. Analytics logging (FR-016)

**Decision**: The backend's assistant controller writes the analytics event itself (via `strapi.entityService.create('api::analytics-event.analytics-event', ...)`) immediately after each AI call resolves, using the `onTopic` flag from the structured response to pick `assistant_question` vs. `assistant_decline`, and a caught exception to log `assistant_error`. Three new `eventType` enum values are added to the existing `analytics-event` content type; no new content type is created.

**Rationale**: The backend already computes the outcome unambiguously (it made the call and parsed the structured result), so logging there avoids a second network round trip from the mobile client purely for telemetry, and avoids the client having to reinterpret the response to decide which event fired. This is the same content type the mobile app already writes to for other events, so it reuses the existing analytics pipeline (dashboard plugin, offline-cache fallback, etc.) without new infrastructure.

**Alternatives considered**: Mobile client calls `Analytics.sendEvent(...)` after receiving the assistant response (rejected: extra round trip, and the client-side offline-cache-and-resend logic could double-count under flaky connectivity in ways the backend-side single write does not).

## 9. In-session conversation state (FR-009, FR-014, clarified reopen behavior)

**Decision**: Conversation history lives only as a JS array property on the QML chat panel component (`ChatIAPanel.qml`, new — see Project Structure), included as `history` in each request to the backend. The backend is stateless per request (no server-side session store). Because the existing chat-panel shell in `HomePage.qml` is only hidden/shown (slid off-screen), never destroyed, on close/reopen within the same app session, a plain QML property naturally persists across that show/hide cycle — matching the clarified requirement with no extra state-management code.

**Rationale**: Matches the already-scaffolded UI behavior (`recChat`'s `anchors.bottomMargin` slide, `visible: anchors.bottomMargin > -parent.height`) with zero new persistence code, and keeps the backend stateless and consistent with how Strapi is used elsewhere in this app.

**Alternatives considered**: Server-side session store keyed by a client-generated session ID (rejected: adds server-side state and a cleanup/expiry concern for zero benefit, since the client already holds the full history it needs to resend); `QtQuick.LocalStorage`-backed persistence (rejected: FR-009 explicitly forbids persistence beyond the app session — a DB-backed store would need explicit clearing logic to comply, whereas a plain in-memory property clears itself for free when the app process ends).

## 10. Environment configuration (Constitution Principle I)

**Decision**: `AssistantHandler.js` imports and reuses `ApiHandler.js`'s existing `baseUrl` constant rather than declaring a third independent hardcoded copy (there are currently two: `ApiHandler.js` and `AnalyticsHandler.js`, already flagged in `CLAUDE.md` as drifted).

**Rationale**: Adding a third independent hardcoded `baseUrl` would actively worsen the exact problem Constitution Principle I calls out. Reusing `ApiHandler.js`'s constant keeps this feature from adding a new instance of the problem, without requiring a full baseUrl-unification refactor (out of scope for this feature — that refactor is a separate, generic tech-debt concern, not something this feature's spec asked for).

**Alternatives considered**: A new independent constant in `AssistantHandler.js` (rejected: directly contradicts Principle I when an existing shared value is one import away); doing the full three-file baseUrl unification as part of this feature (rejected: out of scope per Constitution Principle III — YAGNI — the spec did not ask for this, and bundling an unrelated refactor into this feature's plan risks scope creep the constitution's serialization rule (Principle V) warns against).
