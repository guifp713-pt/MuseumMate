# Feature Specification: Active Museum Entity Selection

**Feature Branch**: `002-content-source-switch`

**Created**: 2026-07-27

**Status**: Draft

**Input**: User description: "Fase 1 — Seleção de Entidade Ativa por documentId: a app e o backend do assistente devem operar sobre uma única entidade escolhida por um documentId centralizado no código, para poder alternar entre o museu fictício e o museu real sem tocar em mais nada. Requisitos funcionais: (1) o sistema deve obter apenas a entidade cujo documentId corresponde a uma constante configurada no código, em vez de buscar todas as entidades e assumir a primeira; (2) essa constante deve existir num único ponto no código (não duplicada); (3) o backend do assistente (assistant-catalog.ts) deve usar a mesma entidade configurada que a app móvel usa — nunca podem divergir; (4) se o documentId configurado não corresponder a nenhuma entidade, o sistema deve mostrar um erro claro em vez de crashar ou mostrar ecrãs vazios sem explicação; (5) a cache local deve ser invalidada quando o documentId configurado muda. Requisitos não-funcionais: não repetir o problema do baseUrl duplicado entre ApiHandler.js/AnalyticsHandler.js; a mudança deve ser reversível em segundos para suportar testes A/B entre o museu fictício e o real; a filtragem deve ocorrer no servidor, não no cliente."

## Clarifications

### Session 2026-07-27

- Q: When the configured active-museum documentId doesn't match any entity, what should the visitor-facing behavior be? → A: The system MUST always operate from a valid, defaulted documentId so the app is never left without data under normal operation; if misconfiguration is nonetheless detected, the app MUST show a clear, blocking error screen (no partial/degraded browsing) rather than ever displaying empty screens.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switch which museum the app serves (Priority: P1)

An operator preparing a build of the app needs it to serve exactly one museum — either the current fictional demo museum or a real museum being onboarded — by changing a single configured value, without touching any other part of the app or backend.

**Why this priority**: This is the core value of the feature — without a single, reliable switch point, every future museum onboarding requires manual, error-prone edits scattered across the codebase.

**Independent Test**: Configure the active museum identifier to museum A, build/install the app, and confirm every screen (maps, tours, areas, items, dictionary) shows only museum A's content. Change the configured identifier to museum B, rebuild/reinstall, and confirm every screen now shows only museum B's content with no trace of museum A.

**Acceptance Scenarios**:

1. **Given** the app is configured to serve museum A, **When** a visitor browses maps, tours, areas, and items, **Then** every screen shows only content belonging to museum A.
2. **Given** the operator changes the single configured identifier from museum A to museum B and rebuilds/reinstalls, **When** the app is opened again, **Then** it shows only museum B's content.
3. **Given** the operator wants to roll back to museum A, **When** they revert the configured identifier to museum A's value and rebuild/reinstall, **Then** the app serves museum A again, with the change taking effect within a single rebuild/reinstall cycle.

---

### User Story 2 - Assistant answers always match the museum on screen (Priority: P1)

A visitor using the in-app assistant expects it to only ever talk about the museum they are currently visiting in the app — never a different museum, even if the backend happens to hold data for more than one.

**Why this priority**: A mismatch between what the app displays and what the assistant talks about would be confusing and would undermine trust in the assistant; this must hold from the first deployment with more than one museum entity in the system.

**Independent Test**: With the active museum configured to museum A, ask the assistant a question whose answer only exists in museum B's catalog, and confirm the assistant does not use museum B's content (it should behave as if that content doesn't exist). Switch the active museum to museum B and confirm the assistant now answers from museum B's catalog only.

**Acceptance Scenarios**:

1. **Given** the app and assistant are both configured to serve museum A, **When** a visitor asks the assistant about the museum, **Then** the answer is drawn only from museum A's catalog.
2. **Given** more than one museum entity exists in the backend, **When** the active museum is switched, **Then** the assistant's answers switch to the newly active museum in the same way the visible app content does, with no configuration step left out.

---

### User Story 3 - Clear error instead of a broken experience on misconfiguration (Priority: P2)

An operator mistypes or misconfigures the active museum identifier (e.g., pointing to a museum entity that was deleted or never existed). A visitor who opens the app in this state should see a clear explanation, not a crash or a silently empty app.

**Why this priority**: Protects visitors from a confusing, unexplained blank experience and gives the operator a fast, unambiguous signal that the configuration is wrong — important for safe rollout, but the app only reaches this state due to a setup mistake, so it ranks below the two core switching behaviors.

**Independent Test**: Configure the active museum identifier to a value that matches no existing museum entity, open the app, and confirm a clear, human-readable error is shown instead of a crash or empty screens.

**Acceptance Scenarios**:

1. **Given** the configured museum identifier does not match any existing museum entity, **When** a visitor opens the app, **Then** the app displays a clear error explaining the museum content could not be found, instead of crashing or showing empty screens without explanation.

---

### User Story 4 - No stale content after switching museums (Priority: P3)

A device that previously downloaded and cached one museum's content must not keep showing that stale content after the operator switches the active museum, even before the visitor manually clears app data.

**Why this priority**: Without this, a rebuilt/reinstalled app could appear to still serve the old museum from cache, silently defeating the switch from User Story 1. It's a supporting/safety requirement rather than the primary value.

**Independent Test**: With museum A's content already cached on a device, switch the active museum to museum B, relaunch the app, and confirm the visitor sees museum B's content rather than museum A's previously cached content.

**Acceptance Scenarios**:

1. **Given** a device has previously cached museum A's content locally, **When** the active museum identifier is changed to museum B, **Then** the next app launch fetches and displays museum B's content rather than reusing museum A's cached content.

---

### Edge Cases

- What happens when the configured active-museum identifier is left blank or malformed? → System MUST treat this the same as "not found" (User Story 3), not crash. This is expected to be rare: the configured value MUST always default to a known-valid documentId, so the app only reaches this state through an explicit operator mistake, never by default.
- What happens if the configured identifier matches a museum entity that exists but has no maps, tours, or items yet (empty content)? → System MUST show the empty museum correctly (empty state), not treat it as a "not found" error.
- What happens if a visitor is mid-session in the app when the active museum is switched on the backend (rather than via app rebuild)? → Out of scope for this phase: the active museum is a build/deploy-time decision (see Assumptions), so a running app session is not expected to hot-switch content.
- What happens to analytics/history collected under the previously active museum after a switch? → Out of scope for this phase; not altered or migrated by this feature.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST serve content (maps, tours, areas, items, dictionary) for exactly one museum entity at a time, determined by a single configured active-museum identifier, rather than retrieving every museum entity in the backend and assuming the first one returned.
- **FR-002**: The active-museum identifier MUST be defined in exactly one place; switching museums MUST be achievable by changing that single value and MUST NOT require edits in more than one location.
- **FR-003**: The in-app assistant MUST resolve its museum catalog from the same active-museum identifier used by the rest of the app, so the assistant and the visible app content can never reference two different museums at once.
- **FR-004**: The configured active-museum identifier MUST always default to a known-valid museum entity, so under normal operation the app is never left without data to show. If, despite this, the configured identifier does not match any existing museum entity, the system MUST present a clear, blocking, human-readable error screen to the visitor — never a crash, and never a partially empty/degraded screen.
- **FR-005**: Locally cached museum content on a visitor's device MUST be invalidated whenever the configured active-museum identifier changes, so a device never continues to display content belonging to a museum that is no longer the active one.
- **FR-006**: Switching the active museum (including reverting to a previously active museum) MUST be a fast, low-effort operation — a single configuration change followed by one rebuild/reinstall cycle — so the same mechanism can support side-by-side comparison between the fictional demo museum and a real museum during rollout.

### Key Entities

- **Museum Entity**: A complete museum's content (maps, tours, areas, items, dictionary), already modeled in the backend; multiple museum entities may coexist, but only one is designated active at a time.
- **Active Museum Configuration**: The single, centrally defined identifier that determines which Museum Entity the app and the assistant currently serve.
- **Local Content Cache**: Museum content stored on a visitor's device for offline/repeat use; must stay tied to whichever Museum Entity is currently active.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can change which museum the app serves by editing exactly one configured value, with the switch fully in effect after a single rebuild/reinstall cycle.
- **SC-002**: Across every app screen and every assistant answer, 100% of displayed museum content belongs to the single currently active museum — zero instances of a different museum's content appearing, verified by manual walkthrough after each switch.
- **SC-003**: 100% of app launches with a misconfigured (non-existent) active-museum identifier show a clear, blocking explanatory error screen, with 0% resulting in a crash, a partial/degraded screen, or an unexplained blank screen.
- **SC-004**: After switching the active museum, 100% of devices with previously cached content show the newly active museum's content on next launch, with 0% showing stale content from the previously active museum.

## Assumptions

- Exactly one museum entity is served per app build/deployment at a time; letting a visitor pick between multiple museums at runtime within the same app install is out of scope for this feature (it is a separate, later capability).
- Switching the active museum is a build/deploy-time operation performed by an operator (change configuration, rebuild/reinstall), not a live, in-session toggle exposed to visitors.
- The identifier used to select a museum entity is whatever unique identifier the backend already uses to distinguish museum entities; this feature does not introduce a new identification scheme.
- The fictional demo museum entity and any real museum entity(ies) already exist, or will exist, as separate entities in the backend; this feature only changes which one is selected, not how museum content is authored or structured.
- Analytics/history data is out of scope for this feature; segmenting analytics by active museum is handled separately.
