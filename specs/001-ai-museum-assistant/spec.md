# Feature Specification: AI Museum Assistant

**Feature Branch**: `001-ai-museum-assistant`

**Created**: 2026-07-17

**Status**: Draft

**Input**: User description: "Criar um Assistente Inteligente (IA) na HomePage da aplicação Museum Mate, especializado exclusivamente no museu. O assistente deve responder a perguntas sobre Áreas, Itens, Tours e restante catálogo existente no Strapi. Deve responder sobre todo o museu, não apenas sobre o item atualmente visualizado. Deve recusar perguntas fora do domínio do museu através de uma instrução de sistema simples. Deve responder automaticamente no idioma ativo do utilizador (PT, EN, ES ou FR). Quando existir tradução oficial no Strapi deve utilizá-la diretamente; quando existir apenas conteúdo em português deverá traduzir a resposta utilizando o modelo de IA. Nesta primeira versão não existe contexto automático da interface, histórico persistente, autenticação nem suporte multimodal. Apenas mensagens de texto. O catálogo é reduzido (~30 itens e ~10 áreas), pelo que será utilizada uma estratégia simples de recuperação do catálogo. É necessária ligação à Internet."

## Clarifications

### Session 2026-07-20

- Q: If the system enforces an internal rate limit to protect the AI provider's free-tier quota, what should the visitor experience when it's hit? → A: No visitor-facing rate limit in this version — any protection is invisible/best-effort and never blocks a message from being sent
- Q: Should assistant interactions be logged anywhere (e.g., for measuring SC-002/SC-003 in production), and if so, how much detail? → A: Log lightweight usage metadata only (event type, language, timestamp) via the existing analytics-event mechanism — never the message text itself
- Q: Does the AI provider used to answer questions and produce translations need to meet a data-residency or compliance constraint (e.g., EU/GDPR data processing)? → A: No data-residency/compliance constraint specified — any capable AI provider may be used; provider selection is a plan-level implementation detail
- Q: If a visitor closes the assistant view and reopens it later in the same app session, what happens to the conversation? → A: The conversation persists in memory for the whole app session — reopening the assistant view shows prior messages from earlier in that session

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ask about anything in the museum, in your own language (Priority: P1)

A visitor on the HomePage opens the assistant and types a question about the museum — an item, an area, a tour, or the catalog in general. The assistant searches the whole museum catalog, not just whatever the visitor happens to be looking at, and replies with a text answer in whichever of the four supported languages (Portuguese, English, Spanish, French) the visitor currently has the app set to.

**Why this priority**: This is the core value the feature exists to deliver — without it there is no assistant.

**Independent Test**: With the app language set to each of PT/EN/ES/FR in turn, open the assistant from the HomePage, ask a question whose answer exists in the catalog, and confirm a correct, same-language text answer is returned — including for catalog content unrelated to the screen the visitor was last on.

**Acceptance Scenarios**:

1. **Given** the visitor's app language is set to English, **When** they ask about a specific museum item, **Then** the assistant returns a text answer describing that item, in English.
2. **Given** the visitor is viewing one exhibit's detail page, **When** they ask the assistant about a different, unrelated tour, **Then** the assistant answers correctly using the full catalog, not just the currently displayed item.
3. **Given** the catalog holds an official translation for the visitor's active language, **When** the assistant answers a question about that content, **Then** the answer uses the official translated text rather than a freshly generated translation.
4. **Given** the catalog only has Portuguese content for the requested topic, **When** the visitor's active language is English, Spanish, or French, **Then** the assistant translates the Portuguese content into the visitor's active language before responding.

---

### User Story 2 - Assistant stays on-topic (Priority: P2)

A visitor asks the assistant something unrelated to the museum. The assistant declines to answer and lets the visitor know it can only help with museum-related questions, instead of attempting to answer as a general-purpose chatbot.

**Why this priority**: Keeps the assistant scoped to its intended purpose and avoids it being used (or perceived) as a general chatbot, which is out of scope for this feature.

**Independent Test**: Ask an off-topic question (e.g., something with no connection to the museum, its exhibits, or visiting it) and confirm the assistant declines and steers the conversation back to museum topics, without attempting to answer the unrelated part.

**Acceptance Scenarios**:

1. **Given** the visitor asks a question unrelated to the museum, **When** the assistant processes it, **Then** it responds with a polite decline that redirects toward museum topics, in the visitor's active language.
2. **Given** the visitor asks a question that is partly museum-related and partly not, **When** the assistant processes it, **Then** it answers the museum-related part and declines the rest.

---

### User Story 3 - Reach the assistant from the HomePage (Priority: P3)

A visitor opens the HomePage and can start a conversation with the assistant right away, without navigating elsewhere in the app, and gets clear feedback if the assistant cannot be reached.

**Why this priority**: Establishes the entry point for the feature; needed for the other stories to be reachable at all, but the answer quality (Stories 1-2) is what delivers the actual value.

**Independent Test**: From the HomePage, open the assistant, send a message, and receive a response without leaving the HomePage flow; separately, with no internet connection, confirm a clear error is shown instead of a silent failure.

**Acceptance Scenarios**:

1. **Given** the visitor is on the HomePage, **When** they open the assistant, **Then** a text conversation view appears where they can type and send a question.
2. **Given** the visitor has no internet connection, **When** they try to send a question to the assistant, **Then** they see a clear message explaining that the assistant needs an internet connection, rather than a silent or confusing failure.
3. **Given** the visitor previously exchanged messages with the assistant and then closed the assistant view without ending the app session, **When** they reopen the assistant view, **Then** their prior messages from earlier in the session are still shown.

---

### Edge Cases

- What happens when the visitor sends an empty or whitespace-only message? The system does not submit it and prompts the visitor to type a question.
- What happens when the assistant finds no matching catalog content for the question? The assistant says it does not have that information rather than inventing an answer.
- What happens if the internet connection drops mid-conversation? The visitor sees a connection-error message and can retry once connectivity returns.
- What happens if the AI or translation service is temporarily unavailable even though the internet connection is fine? The visitor sees a service-unavailable message; the app does not crash or hang.
- What happens if the visitor changes the app's active language mid-conversation? Answers sent after the change use the new language; earlier messages in the conversation are left as they were sent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a text-based conversational assistant accessible from the HomePage.
- **FR-002**: The assistant MUST be able to answer questions about any Area, Item, Tour, or other catalog content in the museum's content system, not only content related to a screen the visitor happens to be viewing.
- **FR-003**: The assistant MUST decline to answer questions outside the museum domain and MUST redirect the visitor toward museum-related topics when this happens.
- **FR-004**: The assistant MUST respond in the visitor's currently active app language (Portuguese, English, Spanish, or French) without requiring the visitor to specify a language.
- **FR-005**: When an official translation for the requested content exists in the visitor's active language, the assistant MUST use that official text rather than generating a new translation.
- **FR-006**: When no official translation exists for the visitor's active language and the underlying content exists in Portuguese, the assistant MUST produce a translated answer in the visitor's active language.
- **FR-007**: The assistant MUST support text input and output only in this version (no voice, image, or other media input or output for the assistant conversation itself).
- **FR-008**: The assistant MUST require an active internet connection to operate and MUST show a clear, non-technical message when the connection is unavailable rather than failing silently.
- **FR-009**: The system MUST NOT persist assistant conversation history beyond the current app session — conversations are not saved once the session ends. Within a single app session, the conversation MUST be kept in memory so that closing and later reopening the assistant view (without ending the app session) shows the visitor's prior messages from earlier in that session.
- **FR-010**: The assistant MUST NOT require the visitor to log in or authenticate to use it.
- **FR-011**: The assistant MUST NOT automatically receive information about which screen or item the visitor is currently viewing; all context for an answer comes from the museum catalog and the visitor's typed question.
- **FR-012**: The assistant's answers MUST be grounded strictly in the museum's catalog content; when the catalog has no information relevant to a museum-domain question, the assistant MUST say it does not have that information rather than supplying answers from general world knowledge.
- **FR-013**: The system MUST display a passive, always-visible notice near the assistant's input (e.g., "Messages are processed by AI") informing visitors that their messages are processed by an AI service; no blocking consent step is required before sending the first message.
- **FR-014**: Within a single open conversation, the assistant MUST retain the in-session message history as context so it can correctly answer follow-up questions that refer back to earlier turns (e.g., "how long does that one take?"); this history MUST NOT be persisted beyond the current app session (see FR-009).
- **FR-015**: When an assistant response was produced via AI translation (per FR-006) rather than official catalog content (per FR-005), the UI MUST display a subtle, non-blocking indicator on that message (e.g., "Automatic translation") in the visitor's active language. No indicator is shown for responses using official translated content.
- **FR-016**: The system MUST record lightweight usage metadata for assistant interactions (e.g., question asked, off-topic decline, error occurred — each with language and timestamp) via the existing analytics-event mechanism, for measuring adoption and the quality-related success criteria. This metadata MUST NOT include the visitor's question text or the assistant's response text, and does not constitute persisted conversation history under FR-009.

### Key Entities *(include if feature involves data)*

- **Assistant Conversation**: A single, in-session exchange between a visitor and the assistant, made up of the visitor's messages and the assistant's responses; exists only for the current app session and is not persisted.
- **Assistant Message**: One turn in a conversation — either the visitor's question or the assistant's text response; a response carries the language it was returned in and whether that text came directly from official catalog content or was translated.
- **Museum Catalog Content**: The existing museum data the assistant draws answers from — entities, areas, items, tours, and their translated text — already managed in the museum's content system; this feature reads it but does not change its structure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Visitors asking about content that exists in the catalog receive a relevant answer within 10 seconds.
- **SC-002**: At least 90% of on-topic test questions spanning all tours, areas, and items in the catalog receive an answer containing correct, catalog-grounded information.
- **SC-003**: 100% of clearly off-topic test questions are declined rather than answered.
- **SC-004**: Visitors receive correctly-languaged answers in all four supported languages (PT, EN, ES, FR), verified with the same set of test questions run once per language.
- **SC-005**: When an official Strapi translation exists for the requested content, 100% of sampled answers use that official text rather than a freshly generated translation.
- **SC-006**: Visitors without an internet connection are shown a clear explanatory message within 5 seconds of attempting to send a question, instead of the app appearing to hang.

## Assumptions

- The catalog stays at roughly its current scale (~30 items, ~10 areas) for this version; a significant catalog growth may require revisiting the retrieval approach in a future version.
- No visitor-facing usage limit or quota messaging is required for this first version. Any internal rate limiting the system applies to protect the AI provider's free-tier quota MUST be invisible to the visitor and MUST NOT block, delay, or produce a distinct error state for a visitor's message; if the AI provider itself becomes unavailable due to quota exhaustion, the visitor sees the standard service-unavailable message (see Edge Cases).
- The assistant is available only while the app has connectivity to both the museum's content system and the AI service it depends on.
- Empty or whitespace-only messages are not submitted to the assistant (client-side guard, not a network round trip).
- "Museum domain" for the on-topic/off-topic distinction covers the museum itself, its history, its exhibits/areas/tours/items, and practical visit information already present in the catalog (e.g., opening hours or location, if such content exists there).
- No data-residency or regulatory-compliance constraint (e.g., EU/GDPR data processing location) is placed on the choice of AI provider for this version; provider selection is left to the implementation plan.
