# Feature Specification: Multi-Museum Analytics Segmentation

**Feature Branch**: `004-analytics-multi-entity`

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "Fase 4 — Dashboard de Analítica Multi-Entidade. Objetivo: hoje o content-type analytics-event e o plugin analytics-dashboard assumem implicitamente que existe uma única entidade (museu) no sistema — nenhum evento sabe a que museu pertence e o dashboard agrega tudo sem segmentação. Com a Fase 1 (seleção de entidade ativa por documentId) e a Fase 2 (segunda entidade real, Museu de Portimão) concluídas, as métricas (visitas, idioma dominante, item mais visitado) tornam-se estatisticamente erradas assim que houver duas entidades a gerar eventos, misturando visitantes de museus diferentes — e não há forma de as separar depois, porque a informação de origem nunca chegou a ser guardada. Além disso, toda a utilização do assistente de IA é invisível no dashboard, apesar de os eventos já serem gravados desde a feature 001."

## Context

Two museums now exist in the system: the original AI-generated fictional entity (kept as
fallback/comparison) and the real Museu de Portimão (feature 002 + Fase 2). Every analytics
event ever recorded, however, is anonymous as to its origin — the event record has no notion
of which museum produced it. As soon as both museums generate traffic, every figure on the
dashboard silently blends two audiences, and the blend is **irreversible**: the origin was
never stored, so it cannot be reconstructed afterwards.

Separately, the AI assistant has been recording its own usage events since feature 001, and
the dashboard has never displayed a single one of them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every event knows which museum it came from (Priority: P1)

As the operator of more than one museum, I need every analytics event — whether it comes from
a visitor's phone or from the AI assistant answering a question — to permanently record which
museum it belongs to, so that today's traffic is still separable tomorrow.

**Why this priority**: This is the only irreversible part of the feature. Metrics displayed
wrongly can be corrected later; origin data that was never captured is lost forever. Every
day this ships later is another day of permanently unattributable events. It delivers value
on its own even before any dashboard change, because it stops the data loss.

**Independent Test**: With both museums configured in turn, produce visitor events from the
app and assistant events from the chat, then inspect the stored records: each one carries the
identifier of the museum that was active when it happened. Pre-existing records carry the
designated legacy label rather than nothing.

**Acceptance Scenarios**:

1. **Given** the system is configured to serve Museu de Portimão, **When** a visitor starts a
   visit, views an item, scans a code or completes a tour, **Then** each recorded event
   identifies Museu de Portimão as its origin.
2. **Given** the system is configured to serve Museu de Portimão, **When** a visitor asks the
   AI assistant a question and the assistant answers, declines, fails, or falls back to
   general knowledge, **Then** the recorded assistant event identifies Museu de Portimão as
   its origin.
3. **Given** analytics events recorded before this feature existed, **When** the change is
   applied, **Then** every one of them carries an explicit museum label and none is left
   blank.
4. **Given** a visitor device holding events queued offline from before the change, **When**
   those events are finally uploaded, **Then** they are accepted and stored, not rejected.

---

### User Story 2 - Read the dashboard for one museum at a time (Priority: P2)

As a museum administrator, I need to choose which museum I am looking at and have every
number on the dashboard refer only to that museum, so that the figures I report are true for
the site I actually manage.

**Why this priority**: This is what turns the captured attribution (US1) into usable
information. It is the visible payoff of the feature, but it depends on US1 having data to
segment, and a wrong number today can be recomputed once the data exists.

**Independent Test**: With both museums holding events, select each museum in turn and verify
that visit totals, the period-over-period comparison, language distribution, most-visited
item, the visits-evolution chart and the top-items chart all change accordingly, and that the
two museums' figures never include each other's visitors.

**Acceptance Scenarios**:

1. **Given** both museums have recorded visits in the active period, **When** the
   administrator selects one museum, **Then** every KPI, table and chart on the page counts
   only that museum's events.
2. **Given** a museum is selected, **When** the administrator switches the active time period
   (today / 7 days / 30 days / year), **Then** the museum selection is preserved and the
   figures stay scoped to it.
3. **Given** a museum is selected, **When** the automatic refresh runs, **Then** it fetches
   only that museum's events and the selection is not reset.
4. **Given** a museum whose item catalogue, combined with the other museum's, exceeds the
   number of items previously retrievable in one go, **When** the top-items chart is shown,
   **Then** every item of the selected museum is displayed by its real name and none appears
   as an unresolved numeric placeholder.
5. **Given** a selected museum with no events in the active period, **When** the dashboard is
   shown, **Then** it displays an explicit empty state rather than an error or another
   museum's data.

---

### User Story 3 - See how the AI assistant is actually being used (Priority: P3)

As a museum administrator, I need the dashboard to show how visitors are using the AI
assistant, broken down by outcome, so that I can tell apart "visitors asking things outside
the museum's scope" from "the assistant is failing" — and see where my catalogue has gaps.

**Why this priority**: Delivers genuinely new visibility (today it is zero), and the
underlying events already exist, so it is pure aggregation and display. It is placed last
because the visitor-traffic metrics are the ones that become *wrong* without this feature,
whereas the AI metrics are merely *absent*.

**Independent Test**: Ask the assistant a set of questions producing each outcome (answerable
from the catalogue, off-domain, forced failure, answerable only from general knowledge), then
confirm the dashboard reports each outcome as its own distinct figure for the selected museum
and period.

**Acceptance Scenarios**:

1. **Given** the assistant has handled questions in the active period, **When** the
   administrator views the dashboard, **Then** a dedicated section reports assistant usage.
2. **Given** assistant events of different outcomes exist, **When** the section is shown,
   **Then** answered questions, off-domain refusals, technical failures and
   general-knowledge fallback answers are each reported as separate figures, never merged
   into one total.
3. **Given** the administrator has selected a museum, **When** the assistant section is
   shown, **Then** it counts only that museum's assistant events and honours the same active
   time period as the rest of the page.
4. **Given** the general-knowledge fallback has been triggered, **When** its count is shown,
   **Then** the administrator can read it as an indicator of catalogue gaps for that museum.

---

### Edge Cases

- **An event arrives with no museum attribution after the change**: not expected in practice
  (no outdated app installation remains in the field — see FR-016's assumption), but if it
  ever happens it signals a defect and must not silently inflate the wrong museum's numbers.
- **A visitor device used at both museums in the same period**: its sessions must be counted
  once per museum, not attributed wholly to either. The language distribution, which weights
  each unique device, must therefore weight per museum.
- **A legacy event referencing an item that belongs to a different museum**: the item name
  cannot be resolved within the selected museum's catalogue and must degrade to a readable
  placeholder rather than showing another museum's item name.
- **The configured museum is changed between two visits on the same device**: earlier events
  keep their original attribution and are not retroactively relabelled.
- **A museum with no events at all**: it must still be selectable and must show an empty
  state, not an error.
- **A museum record is deleted while its events remain**: the events must remain readable and
  identifiable rather than becoming invisible.

## Requirements *(mandatory)*

### Functional Requirements

#### Event attribution (US1)

- **FR-001**: Every analytics event MUST record which museum it originated from, as a
  first-class part of the event record. *(Fase 4 → FR-4.1)*
- **FR-002**: The museum identifier written onto an event MUST be the same centrally
  configured active-museum identifier the system already uses to decide which museum's
  content to serve. No component may introduce a second, independently maintained copy of
  that identifier. *(Fase 4 → FR-4.2, NFR-4.1)*
- **FR-003**: Both producers of analytics events MUST attribute them: the visitor mobile
  application (visit, item view, tour and scan events) and the server-side AI assistant
  (question, refusal, error and general-knowledge fallback events). Neither may be left
  unattributed. *(extends Fase 4 → FR-4.2, which named only the mobile producer)*
- **FR-004**: Introducing the attribution MUST be purely additive to the event record —
  nothing existing may be removed or renamed — so that events already queued offline on
  visitor devices remain acceptable when they are eventually uploaded. *(Fase 4 → NFR-4.2)*
- **FR-005**: Analytics events recorded before this feature MUST be explicitly labelled with
  the original fictional museum rather than left blank, so they neither disappear from
  statistics nor get counted under the wrong museum once filtering is in force.
  *(Fase 4 → FR-4.6)*
- **FR-016**: No outdated installation of the mobile app remains in the field — every device
  is updated together with this change, so every event produced after this feature ships is
  expected to carry attribution by construction. Any event that nonetheless arrives without
  attribution after rollout is therefore a defect, not a legitimate scenario to design around;
  the system MUST make such an event visibly detectable (e.g. a clear log entry) rather than
  silently accepting it into any museum's statistics.

#### Dashboard segmentation (US2)

- **FR-006**: Administrators MUST be able to select which museum's analytics they are
  viewing, from within the dashboard. *(Fase 4 → FR-4.3)*
- **FR-017**: The dashboard MUST open, by default, on the currently configured active museum.
  No aggregate "All museums" view is offered — the selector lists individual museums only, in
  keeping with the Simplicity/YAGNI principle; an aggregate view can be added later if a
  concrete need for one arises.
- **FR-007**: Every derived figure on the dashboard MUST be scoped to the selected museum —
  visit totals, the previous-period comparison, language distribution, most-visited item, the
  visits-evolution chart and the top-items chart. *(Fase 4 → FR-4.3)*
- **FR-008**: The dashboard MUST request only the selected museum's events from the server,
  rather than retrieving every museum's events and discarding the unwanted ones after the
  fact. *(Fase 4 → FR-4.4, NFR-4.3)*
- **FR-009**: The item-name lookup that turns event references into readable item names MUST
  be scoped to the selected museum and MUST resolve every one of that museum's items,
  regardless of how many items exist across all museums combined. *(Fase 4 → FR-4.5)*
- **FR-010**: The existing per-language session-statistics endpoint, which is currently called
  by no client (the dashboard computes language distribution itself), MUST be removed rather
  than scoped for a use it does not have — per the Simplicity/YAGNI principle, an unused
  endpoint that could return figures mixed across museums is a liability, not an asset to
  maintain forward. *(Fase 4 → FR-4.7, superseded by this decision)*
- **FR-015**: Museum scoping MUST NOT degrade the dashboard's existing paging or automatic
  refresh behaviour; switching museum or period MUST NOT require a full page reload.
  *(Fase 4 → NFR-4.3)*
- **FR-014**: The dashboard MUST reach its data source through a single configured value
  rather than an address hardcoded at each call site, in line with the project's environment
  configuration discipline. *(new — found during analysis; the affected calls are the same
  ones FR-008 and FR-009 rewrite)*

#### Assistant metrics (US3)

- **FR-011**: The dashboard MUST report AI assistant usage, which is currently not surfaced
  anywhere. *(Fase 4 → FR-4.8)*
- **FR-012**: Assistant metrics MUST report, as separate figures, at minimum: questions
  answered, questions refused for being outside the museum's domain, technical failures, and
  answers produced from the model's general knowledge rather than the catalogue. These MUST
  NOT be merged into a single total. *(Fase 4 → FR-4.9, FR-4.11)*
- **FR-013**: Assistant metrics MUST honour the same museum selection and the same active
  time period as the rest of the dashboard. *(Fase 4 → FR-4.10)*
- **FR-018**: Assistant metrics MUST be derived from the events already being recorded — this
  feature MUST NOT require a new event kind or a change to how assistant events are
  classified. *(Fase 4 → NFR-4.5)*

### Key Entities

- **Analytics Event**: a single recorded visitor or assistant action. Already carries what
  happened, when, in which language, under which session, and for which item/tour where
  applicable. This feature adds **which museum it belongs to** as a permanent part of it.
- **Museum (Entity)**: the root record per museum. Already the unit by which content is
  served; this feature makes it also the unit by which analytics are counted and read.
- **Active Museum Selection**: the single centrally configured identifier that decides which
  museum the system currently serves. This feature makes it the value stamped onto every new
  event; it is *not* the same thing as the museum an administrator picks for *viewing* on the
  dashboard, which may be any museum, past or present.
- **Item Name Lookup**: the mapping from an event's item reference to a human-readable item
  name shown in the dashboard. This feature scopes it to the selected museum.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With both museums generating traffic in the same period, 100% of newly recorded
  events can be traced to exactly one museum, and 0% are ambiguous.
- **SC-002**: After the change, no pre-existing analytics event is lost: the combined total
  across all museums equals the total that was visible before the change.
- **SC-003**: With a museum selected, 0 events belonging to any other museum contribute to
  any figure on the page — verified by comparing each museum's figures against manually
  counted events for that museum.
- **SC-004**: An administrator can switch between museums and see the fully updated dashboard
  within 3 seconds, without reloading the page and without losing the selected time period.
- **SC-005**: With two museums in the database, the dashboard becomes ready to read no slower
  than it did with one museum — the second museum's data must not add to the wait.
- **SC-006**: 100% of the selected museum's items appear under their real names in the
  top-items chart, with no unresolved numeric placeholders, even when the two museums'
  catalogues combined exceed the previously retrievable number of items.
- **SC-007**: The dashboard reports at least four distinct assistant outcome figures
  (answered, refused as off-domain, technical failure, general-knowledge fallback), each
  independently readable for the selected museum and period.
- **SC-008**: An administrator can answer "is this spike visitors asking off-topic questions,
  or is the assistant broken?" from the dashboard alone, without inspecting raw event
  records.

## Assumptions

- The museum identifier used for attribution is the one already centralised by feature 002
  (`002-content-source-switch`); this feature reuses it and does not introduce a parallel
  identifier scheme.
- Dashboard users are trusted museum staff with access to the administration panel; per-museum
  access restrictions (staff of museum A being unable to see museum B) are **out of scope** —
  the selector shows all museums to everyone who can open the dashboard.
- The number of museums stays small (currently two, expected to remain in the single digits),
  so the selector can list them without search or pagination.
- Historical events predating this feature all belong to the original fictional museum, since
  it was the only museum in existence while they were produced.
- No outdated installation of the mobile app remains in the field once this feature ships —
  every device receives the updated app together with this change, so there is no fleet of
  older clients producing unattributed events over time. This is a confirmed operational fact
  about the current deployment, not a risk being accepted.
- The active period selector (today / 7 days / 30 days / year) and the proportional
  per-device language weighting already in the dashboard are retained as they are; this
  feature scopes them by museum rather than redesigning them.
- No automated test suite exists on either stack (per the constitution), so acceptance is by
  manual end-to-end verification with both museums populated.
- Realistic validation of segmentation requires both museums to be generating events; the
  fictional museum's existing history plus new Museu de Portimão traffic is considered
  sufficient for this. *(Fase 4 → NFR-4.4)*

## Dependencies

- **Feature 002 (`002-content-source-switch`)** — complete. Provides the single centrally
  configured active-museum identifier that FR-002 requires. Without it there would be nothing
  authoritative to stamp onto events.
- **Fase 2 (real museum content)** — complete. Provides the second populated museum needed to
  validate segmentation with real data rather than an artificially duplicated entity.
- **Feature 003 (`003-assistant-web-fallback`)** — complete; **not a blocker**. Its
  general-knowledge fallback event kind already exists, so FR-012 can count it immediately
  instead of merely preparing for it. This feature can proceed in parallel with any remaining
  end-to-end validation of 003.

## Out of Scope

- Per-museum access control or roles in the administration panel.
- Retroactively reconstructing the true origin of pre-existing events (impossible — the
  information was never captured; FR-005 labels them by convention, not by recovery).
- Redesigning the existing visit/language/item metric definitions or the proportional
  per-device language weighting.
- New event kinds, or changing how the assistant classifies its own outcomes.
- Cross-museum comparison views (museum A vs museum B side by side) and any aggregate
  "all museums" view (per FR-017).
