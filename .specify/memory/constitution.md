<!--
Sync Impact Report
==================
Version change: TEMPLATE (unratified) → 1.0.0
Rationale for 1.0.0: Initial concrete ratification of a previously all-placeholder
template — first defined set of governing principles, not an amendment.

Modified principles: n/a (all four are newly defined; template placeholders had no prior content)
Added principles:
  - I. Environment Configuration Discipline
  - II. Cross-Stack Consistency
  - III. Simplicity / YAGNI
  - IV. Spec-Driven Development (NON-NEGOTIABLE)
Removed principles: none

Added sections:
  - Technology Stack Constraints (replaces [SECTION_2_NAME])
  - Development Workflow & Quality Gates (replaces [SECTION_3_NAME])
Removed sections: none

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check gate is derived
     dynamically from this file; no hardcoded principle references to update.
  ✅ .specify/templates/spec-template.md — reviewed, no principle-specific
     content to reconcile.
  ✅ .specify/templates/tasks-template.md — reviewed; its "parallel team"
     guidance describes how a single approved task's subtasks may be split,
     not concurrent unapproved features, so it does not conflict with
     Principle IV. No edit needed.
  ✅ .claude/skills/speckit-*/SKILL.md — scanned for agent-specific/outdated
     references; none found outside this command's own self-check instructions.
  ✅ CLAUDE.md (repo root) — reviewed; already documents the two-stack
     (Qt/QML mobile + Strapi backend) architecture consistent with the
     Technology Stack Constraints section below. No contradictions found.

Follow-up TODOs: none — all placeholders were resolved from user-provided
answers in this session.
-->

# Museum Mate Constitution
<!-- Museum Mate: Qt/QML museum-tour mobile app + Strapi backend monorepo -->

## Core Principles

### I. Environment Configuration Discipline

Network endpoints, API base URLs, and other environment-dependent values MUST NOT
be hardcoded as the sole committed value in application source. Such values MUST
be externalized (a single designated config file, build-time setting, or
environment variable) so that switching networks or environments does not require
editing and recommitting source files. Where more than one file currently needs an
environment value, they MUST read from one shared, designated source — not
maintain independent copies.

**Rationale**: `ApiHandler.js` and `AnalyticsHandler.js` each hardcode their own
LAN-IP `baseUrl` with commented alternatives for different networks, and the two
have already drifted out of sync with each other. This principle exists to
converge on a single source of truth instead of editing IPs in multiple places
per deployment.

### II. Cross-Stack Consistency

Data contracts crossing the Strapi (TypeScript) ↔ mobile (QML/JS) boundary MUST be
normalized at a single, documented boundary layer rather than re-interpreted ad
hoc at each call site. Response-shape handling (e.g., Strapi's `data`/`attributes`
wrapping vs. flat objects), field naming, and relation-population conventions MUST
be applied uniformly across the client.

**Rationale**: `ApiHandler.js` currently repeats `rawData.attributes || rawData`
-style defensive shape-checking in nearly every function. A single normalization
point reduces the risk of the two stacks silently diverging as either side
changes.

### III. Simplicity / YAGNI

Functional correctness and an intuitive user experience take precedence over minimizing implementation complexity.
When multiple solutions satisfy the expected product quality, the simplest solution SHOULD be preferred.
Do not introduce speculative abstractions, new frameworks, admin plugins, or generic layers for hypothetical future requirements. Every new dependency or Strapi plugin MUST be justified by a concrete, present need.

Rationale:
Museum Mate prioritizes delivering a correct, intuitive experience for museum visitors.
KISS and YAGNI are decision filters applied after the expected behaviour has been achieved, not reasons to reduce product quality or remove behaviour users naturally expect.
This keeps the codebase maintainable without sacrificing usability.

### IV. Maintainable Design

New components, services and modules SHOULD follow the SOLID principles whenever
applicable. Each component MUST have a clear and focused responsibility,
dependencies SHOULD be inverted through well-defined abstractions when doing so
improves maintainability, and implementations SHOULD be designed to allow
extension without requiring modification of existing behaviour. SOLID must always
be applied pragmatically, balancing maintainability and extensibility with the
principles of KISS and YAGNI to avoid unnecessary abstraction.

**Rationale**: Consistently applying SOLID produces a modular, maintainable and
extensible architecture while reducing coupling and improving code readability.
These principles complement KISS and YAGNI rather than encouraging excessive
abstraction.


### V. Spec-Driven Development (NON-NEGOTIABLE)

All features MUST proceed through the Spec Kit workflow — specify → clarify →
plan → tasks → implement — before implementation begins. No implementation work
starts without an approved spec and task list. Only one approved task may be
actively in implementation at a time; work MUST be serialized rather than run as
multiple concurrent, half-finished features.

**Rationale**: keeps solo/small-team work traceable across two independently
versioned stacks and prevents partially-implemented, undocumented changes from
accumulating in either the mobile app or the backend.

## Technology Stack Constraints

- **Mobile app**: Qt 6 / QML / C++17, built via the qmake project
  `AssistentTourPhone.pro`, targeting Android (arm64-v8a, armeabi-v7a) and
  Desktop. QR scanning depends on the vendored/submoduled `qzxing` library.
- **Backend**: Strapi 5 on Node.js (`>=20.0.0 <=24.x.x`) with TypeScript,
  `better-sqlite3` as the default database driver, run locally via Docker
  Compose (`backend/docker-compose.yml`).
- Content types follow the i18n-localized convention
  (`pluginOptions.i18n.localized`) already established across existing
  collection types; new content types SHOULD follow this pattern unless there
  is a specific reason not to localize a given field.
- Replacing the mobile UI framework (away from QML), the backend CMS (away from
  Strapi), or the QR library REQUIRES a constitution amendment — not a silent
  substitution.

## Development Workflow & Quality Gates

- Features are tracked as Spec Kit artifacts under `specs/[###-feature-name]/`
  (`spec.md`, `plan.md`, `tasks.md`); implementation MUST reference the approved
  plan/tasks rather than proceeding from an undocumented understanding of the
  request.
- `CLAUDE.md` at the repo root is the canonical architecture/commands reference
  for AI agents working in this repo and MUST be kept in sync when architecture,
  commands, or major conventions change as part of a feature's implementation.
- Neither stack currently has an automated test suite. Changes MUST therefore be
  manually verified end-to-end before being considered complete; adding
  automated tests for a touched area is encouraged but not yet mandatory.
- Every feature plan MUST include a Constitution Check gate (per
  `plan-template.md`) confirming compliance with the principles above before
  implementation proceeds; any violation MUST be justified in the plan's
  Complexity Tracking table or the plan is rejected.

## Governance

This constitution supersedes ad hoc conventions when the two conflict.
Amendments are made via the `/speckit-constitution` command and MUST: (a) update
the version per the semantic versioning policy below, and (b) propagate to
dependent templates and docs (plan/spec/tasks templates, `CLAUDE.md`) in the same
change.

**Versioning policy**:
- **MAJOR** — backward-incompatible governance changes, or removal/redefinition
  of an existing principle.
- **MINOR** — a new principle or materially expanded section is added.
- **PATCH** — wording clarifications, typo fixes, non-semantic refinements.

Use `CLAUDE.md` for day-to-day runtime development guidance (build/run commands,
architecture detail); use this constitution for governing principles and
workflow requirements that guidance must not contradict.

**Version**: 1.1.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-17
