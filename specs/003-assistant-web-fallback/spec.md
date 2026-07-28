# Feature Specification: Assistant General-Knowledge Fallback

**Feature Branch**: `003-assistant-web-fallback`

**Created**: 2026-07-27

**Status**: Draft

> **Pivot note (2026-07-27):** this spec was originally written around a **web
> search** fallback (Gemini Google Search grounding). Grounding requires an active
> billing account on the API key, which this (academic) deployment deliberately
> avoids, so the second step was changed to a **general-knowledge fallback**: a
> plain model call that answers from the model's own trained knowledge when the
> catalog can't, with the catalog kept authoritative. See `research.md §1/§2`.
>
> **Read this spec with that substitution in mind:** wherever it says "web
> search" / "external search" / "external source", read "the model's own
> general-knowledge answer (outside the catalog)". Every *behavioral* requirement
> below still holds unchanged — catalog-first (FR-001), three-way classification
> (FR-002), catalog precedence on conflict (FR-008), the off-domain decline
> guardrail (FR-004/FR-012), the "don't invent" rule (FR-009), the visible
> non-catalog indicator (FR-007), the central disable switch (FR-011), and one
> analytics event per fallback (FR-010). Only the *mechanism* (how the second
> step gets its information) changed, plus the concrete names: the eventType is
> `assistant_knowledge_fallback`, the switch is `KNOWLEDGE_FALLBACK_ENABLED`, and
> the response field is `usedGeneralKnowledge`.

**Input**: User description: "Fase 3 — IA com Fallback de Pesquisa Web (mantendo o guardrail de domínio). O assistente do museu continua a usar o catálogo do Strapi como fonte primária e autoritativa das respostas. Quando o catálogo não contém informação suficiente para responder a uma pergunta que ainda está dentro do domínio do museu, o sistema deve poder complementar a resposta com uma pesquisa externa na web, sem nunca passar a comportar-se como um chatbot genérico. Classificar cada pergunta em três categorias: (a) respondível pelo catálogo, (b) sobre o museu mas não coberta pelo catálogo (candidata a pesquisa externa), (c) fora do domínio do museu (recusar). Quando ocorrer pesquisa externa, construir a query de forma restrita, nunca a pergunta em bruto. Identificar de forma visível ao visitante quando uma resposta usou pesquisa externa. Em caso de conflito, o catálogo tem sempre prioridade. O guardrail de recusa de perguntas fora do domínio deve continuar a aplicar-se integralmente. Registar via analytics um novo eventType (assistant_web_fallback) sempre que a pesquisa externa for acionada."

## Clarifications

### Session 2026-07-27

- Q: When a question sits on the boundary between "museum-related but not covered by the catalog" and "off-domain", what should the assistant do by default? → A: Default to attempting a restricted web search whenever there is a plausible connection to the museum — the assistant only declines a question when it has no plausible museum connection at all. The query-restriction rule (FR-006) is the primary safeguard against drift for these boundary cases, since more of them will now reach the search step than would reach a decline.
- Q: What is the acceptable latency for an answer that required a web search, and is a "searching…" UI indicator required? → A: A dedicated success criterion of under 20 seconds end-to-end applies to the web-search path, and the UI MUST show a visible "searching…" (or equivalent) indicator whenever the wait is expected to exceed the catalog-only path's normal response time.
- Q: Given the open cost/quota question for web search (NFR-3.2 in the phase notes), should the system have an operator-controlled way to turn the web-fallback capability off entirely without a code change? → A: Yes — a single centrally-defined on/off switch (config-level, like the active-museum documentId from feature 002) that disables web fallback everywhere at once when flipped, defaulting to off until explicitly enabled for a deployment.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Get an answer when the catalog falls short, but only for museum questions (Priority: P1)

A visitor asks the assistant something that is clearly about the museum — its history, an exhibit, the building, a related fact — but the museum's own catalog doesn't contain enough to answer it. Instead of saying "I don't know" outright, the assistant recognizes the question is still within the museum's domain, performs a narrowly-scoped external search, and returns an answer that is clearly marked as coming from outside the catalog.

**Why this priority**: This is the entire value proposition of the feature — without it, the feature does nothing beyond what already exists.

**Independent Test**: Ask a question that is unambiguously about the museum's domain (e.g., a historical fact about the museum building or the wider context of an exhibit) but that does not appear anywhere in the catalog content, and confirm the assistant returns a relevant, correctly-sourced answer with a visible external-source indicator, within the web-search latency target.

**Acceptance Scenarios**:

1. **Given** a visitor asks a clearly museum-related question with no matching catalog content, **When** the assistant processes it, **Then** it performs an external search restricted to the museum's context, returns an answer, and visibly marks that answer as coming from an external search rather than the verified catalog.
2. **Given** the same scenario, **When** the external search itself finds nothing conclusive, **Then** the assistant tells the visitor it doesn't have that information rather than inventing an answer.
3. **Given** the web-fallback capability is administratively disabled (see FR-011), **When** a visitor asks a question that would otherwise trigger a web search, **Then** the assistant responds exactly as it did before this feature existed (catalog-only, or "I don't have that information").

---

### User Story 2 - The domain guardrail still holds with search enabled (Priority: P1)

A visitor asks the assistant something with no connection to the museum (e.g., a personal question, general trivia, or a request unrelated to visiting). Even though the assistant now has the ability to search the web, it still declines exactly as it did before this feature existed, rather than treating "I can search the web" as a reason to answer anything.

**Why this priority**: This is the guardrail the whole feature is designed around preserving. Regressing it — even occasionally — would turn the assistant into a general-purpose chatbot, which is explicitly out of scope for this product. It ranks alongside Story 1 because shipping search without this holding is a net loss, not a smaller version of the feature.

**Independent Test**: Run the same off-topic test questions used to validate the original domain guardrail (feature 001, User Story 2) against the assistant with web fallback enabled, and confirm every one is still declined, none trigger an external search, and none are answered using outside knowledge.

**Acceptance Scenarios**:

1. **Given** a visitor asks a question entirely unrelated to the museum, **When** the assistant processes it, **Then** it declines exactly as before — it does not perform a web search and does not answer from general knowledge.
2. **Given** a question that sits on the boundary between "museum-related" and "off-domain" but still has a plausible connection to the museum, **When** the assistant evaluates it, **Then** it attempts a restricted web search rather than declining outright (see Clarifications, Session 2026-07-27); a question is only declined when it has no plausible museum connection at all.
3. **Given** a visitor asks a question that is partly museum-related and partly not, **When** the assistant processes it, **Then** it may use web search only for the museum-related part, per the existing partial-decline behavior (feature 001, User Story 2), and still declines the unrelated part.

---

### User Story 3 - The catalog always wins on conflict (Priority: P2)

A visitor asks a question where the museum's own catalog has information and an external search would also turn up something — possibly different or outdated. The assistant's answer must always reflect the catalog's version, never let external information override or contradict verified museum content.

**Why this priority**: Protects the trustworthiness of catalog content, which is the museum's own verified information; without this, a visitor could be told something that contradicts what the museum itself has published, which is a curatorial and trust problem, not just a UX one.

**Independent Test**: Construct or identify a question where the catalog holds a specific fact and confirm the assistant's answer matches the catalog even when external search is available and would return conflicting information; separately, confirm web search is only attempted when the catalog genuinely lacks relevant content (Story 1), not as a way to "double check" catalog answers.

**Acceptance Scenarios**:

1. **Given** the catalog contains a relevant, sufficient answer to the visitor's question, **When** the assistant responds, **Then** it uses the catalog content and does not perform a web search at all.
2. **Given** a rare situation where both catalog content and a web search result are available for the same question, **When** the assistant composes its answer, **Then** the catalog's version takes precedence and any conflicting external detail is omitted rather than surfaced.

---

### User Story 4 - Catalog gaps become visible to whoever curates content (Priority: P3)

Every time the assistant has to fall back to an external search, that is a signal that the museum's own catalog is missing something visitors actually ask about. This should be captured so it can inform what to add to the catalog next (for this museum or future ones), without requiring anyone to comb through conversation transcripts (which aren't persisted, per feature 001).

**Why this priority**: Valuable for long-term content quality but not required for the feature to work correctly on day one; it's a supporting signal, not a visitor-facing behavior.

**Independent Test**: Trigger a web-fallback answer, then confirm a corresponding analytics event was recorded with enough information (language, timestamp, and an outcome indicator) to later identify that a content gap occurred, without containing the visitor's question or answer text.

**Acceptance Scenarios**:

1. **Given** the assistant answers a question using external search, **When** the response is returned, **Then** an analytics event distinguishable from ordinary catalog answers is recorded.
2. **Given** the web-fallback capability is administratively disabled (FR-011), **When** a question would have qualified for web fallback, **Then** no web-fallback analytics event is recorded (there was no fallback), consistent with the assistant behaving as it did before this feature.

---

### Edge Cases

- What happens when the external search service itself is unavailable or errors out? The assistant tells the visitor it doesn't have that information (same as a catalog miss), rather than surfacing a technical error or hanging indefinitely.
- What happens when the external search takes noticeably longer than a catalog-only answer? The visitor sees a visible "searching…" (or equivalent) indicator rather than an unexplained wait (see Clarifications).
- What happens if the visitor's active language has no good external search results (e.g., a niche museum fact only documented in one language)? The assistant may still translate a found result into the visitor's active language, following the same translation-indicator pattern already used for catalog translations (feature 001, FR-006/FR-015), and MUST still mark it as externally-sourced in addition to the translation indicator if both apply.
- What happens if a visitor rapidly asks several questions that each require a web search? Each is handled independently on its own merits; this feature does not introduce a visitor-facing rate limit (consistent with feature 001's Assumptions), though the web-fallback capability as a whole can still be disabled centrally (FR-011) if cost/quota requires it.
- What happens to the existing partial on-topic/off-topic behavior (feature 001, US2 Acceptance Scenario 2) when web fallback is enabled? It is unchanged in kind — only the "on-topic but not in catalog" portion of a mixed question may now use web search instead of always producing "I don't have that information."

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The assistant MUST continue to attempt an answer using only the museum catalog first, exactly as it does today (feature 001, FR-012); web search MUST NOT be attempted for a question the catalog can already answer.
- **FR-002**: Before deciding how to respond, the system MUST classify each question into exactly one of three categories: (a) answerable from the catalog, (b) about the museum but not covered by the catalog, or (c) outside the museum domain.
- **FR-003**: When a question is classified as (b), the assistant MUST perform an external web search before concluding it has no answer.
- **FR-004**: When a question is classified as (c), the assistant MUST decline exactly as it does today (feature 001, User Story 2) and MUST NOT perform a web search for that question.
- **FR-005**: When a question's classification between (b) and (c) is not clearly settled, the system MUST resolve the ambiguity by classifying it as (b) (attempt a restricted web search) rather than (c) (decline) — the assistant only declines a question when it has no plausible connection to the museum domain at all.
- **FR-006**: The general-knowledge fallback MUST be scoped to the museum, not opened up to the visitor's raw wording as an open-ended prompt. The system MUST derive a restricted topic (`searchTopic`, e.g. combining the museum's subject with the question's topic) during classification and use it to focus the fallback call's system instruction on that topic in connection with the active museum — so the model answers the museum-scoped question, never drifts into unrelated general-knowledge territory the visitor's phrasing might suggest. *(Originally this constrained a search-engine query; with no search engine, the same intent is enforced through prompt-level topic scoping.)*
- **FR-007**: Every assistant response that used an external search result MUST carry a visible, distinct indicator to the visitor identifying the answer as sourced from outside the museum's verified catalog, separate from and in addition to any existing translation indicator (feature 001, FR-015).
- **FR-008**: When both catalog content and an external search result are relevant to the same question, the assistant's answer MUST reflect the catalog content, and any conflicting detail from the external search MUST be omitted rather than shown alongside it.
- **FR-009**: When a question is classified as (b) and the external search returns no conclusive result, the assistant MUST tell the visitor it does not have that information rather than answering from general knowledge or inventing an answer.
- **FR-010**: The system MUST record an analytics event (distinguishable from existing `assistant_question`/`assistant_decline`/`assistant_error` events, i.e. `assistant_knowledge_fallback`) each time the general-knowledge fallback is performed, following the existing lightweight-metadata pattern (feature 001, FR-016) — language and timestamp only, never the visitor's question or the assistant's answer text.
- **FR-011**: The system MUST provide a single, centrally-defined configuration switch (`KNOWLEDGE_FALLBACK_ENABLED`) that enables or disables the entire fallback capability at once; while disabled, every question classified as (b) MUST be handled exactly as it would be if this feature did not exist (i.e., "I don't have that information"), and no `assistant_knowledge_fallback` analytics event MUST be recorded.
- **FR-012**: The domain guardrail behavior already defined in feature 001 (User Story 2, decline of off-domain questions, partial decline of mixed questions) MUST continue to apply unchanged for every question classified as (c), regardless of whether web fallback is enabled.
- **FR-013**: The assistant's response contract MUST gain the ability to signal "this answer used external search" as an additive extension; existing consumers of the response that do not look for this new signal MUST continue to work unchanged (no existing field removed, renamed, or repurposed).

### Key Entities *(include if feature involves data)*

- **Question Classification**: The outcome of evaluating one visitor question against the museum domain and the catalog's coverage — one of "answerable from catalog", "museum-related but uncovered", or "off-domain" — decided before a response strategy is chosen.
- **Restricted Topic (`searchTopic`)**: The short, system-derived topic phrase (never the visitor's raw text) that scopes the general-knowledge fallback to the museum when a question is classified as "museum-related but uncovered".
- **General-Knowledge Answer**: Information produced by the model's own trained knowledge (not the catalog) in the fallback step; carries lower trust than catalog content and must remain distinguishable from it in the final answer.
- **Assistant Message (extended)**: The existing per-turn response record from feature 001, gaining an additional, optional indicator (`usedGeneralKnowledge`) of whether the message's content came from the model's general knowledge rather than the catalog.
- **Fallback Configuration**: The single centrally-defined on/off switch (`KNOWLEDGE_FALLBACK_ENABLED`) that governs whether the general-knowledge fallback capability is available at all for a given deployment.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Visitors asking a clearly museum-related question not covered by the catalog receive a relevant, correctly-sourced answer within 20 seconds when web fallback is enabled.
- **SC-002**: 100% of off-topic test questions from feature 001's original test set (SC-003) are still declined with web fallback enabled, with zero instances of an external search being triggered for those questions.
- **SC-003**: 100% of sampled answers that used external search display a visible external-source indicator to the visitor.
- **SC-004**: In sampled questions where both catalog content and a plausible external result exist, 100% of answers reflect the catalog's version with no conflicting external detail shown.
- **SC-005**: 100% of external-search answers produce a distinct, identifiable analytics event, with zero such events recorded while the web-fallback configuration switch is disabled.
- **SC-006**: An operator can disable the entire web-fallback capability by changing a single configuration value, with the assistant's behavior reverting fully to its pre-feature (catalog-only) behavior with no further changes.

## Assumptions

- Feature 002 (active museum entity selection) is already in place, so "the museum" for classification and query-restriction purposes is unambiguous at any given time.
- The specific external search mechanism/provider (e.g., a search API or an AI provider's built-in grounding capability) and its cost/quota characteristics are an implementation/plan-level decision; this specification only constrains its behavior (restricted query, catalog-priority, visible sourcing, disable switch), not its provider.
- The visitor-facing external-source indicator follows the same passive, non-blocking presentation style already used for the "automatic translation" indicator (feature 001, FR-015) rather than introducing a new interaction pattern.
- No new visitor-facing rate limit is introduced by this feature, consistent with feature 001's existing assumption; the operator-level disable switch (FR-011) is the mechanism for controlling cost/quota exposure, not a per-visitor limit.
- The three-way question classification and the decision of whether to search are internal assistant behavior; no new UI is required for the visitor to see or influence the classification itself, beyond the existing conversation view and the new external-source indicator.
