# Quickstart: Validating Active Museum Entity Selection

## Prerequisites

- Strapi backend running locally (`npm run develop` in `backend/app/`) with
  at least two `entidade` documents: the existing fictional demo museum
  (documentId `gqag59gr2pvu95qawb4dq1ol`) and the second, real museum entity
  currently being populated (maps, areas, items) in parallel with this feature.
- Mobile app buildable/runnable (Qt Creator or `qmake && make`, Desktop or
  Android target).

## Scenario 1 — App and assistant serve the configured museum

1. Set `ACTIVE_ENTITY_DOCUMENT_ID` in both `ApiHandler.js` and
   `backend/app/src/config/museum.ts` to the fictional demo museum's documentId.
2. Rebuild/reinstall the app; restart the backend.
3. Open the app → confirm the language-selection screen and, after picking a
   language, every screen (maps, tours, areas, items) shows only the demo
   museum's content.
4. Ask the in-app assistant a question about the demo museum → confirm the
   answer is drawn from the demo museum's catalog.

**Expected**: No trace of the second (real) museum anywhere in the app or in
assistant answers.

## Scenario 2 — Switching to the new museum

1. Change `ACTIVE_ENTITY_DOCUMENT_ID` in **both** owning locations to the new
   (real) museum entity's documentId.
2. Rebuild/reinstall the app; restart the backend.
3. Open the app on a device that previously ran Scenario 1 (i.e., already has
   cached content for the old documentId).
4. Confirm the app shows the new museum's maps/tours/areas/items — not the
   previously cached demo-museum content.
5. Ask the assistant a question about the new museum → confirm the answer
   comes from the new museum's catalog, not the demo museum's.

**Expected**: This is the exact validation the feature exists to support —
changing one configured value (in both places) and rebuilding is enough to
fully switch which museum the app and assistant serve, with no stale cached
content left over from Scenario 1 (validates FR-005 / User Story 4).

## Scenario 3 — Reverting (A/B comparison)

1. Change `ACTIVE_ENTITY_DOCUMENT_ID` back to the demo museum's documentId in
   both locations.
2. Rebuild/reinstall.
3. Confirm the app serves the demo museum again.

**Expected**: The switch is reversible within one rebuild/reinstall cycle
(SC-001), supporting side-by-side comparison during rollout.

## Scenario 4 — Misconfiguration

1. Set `ACTIVE_ENTITY_DOCUMENT_ID` (mobile side only, to simulate a mistake)
   to a value that matches no existing `entidade` (e.g., append `_typo`).
2. Rebuild/reinstall the app.
3. Open the app.

**Expected**: A clear, blocking error screen is shown instead of the
language-selection screen or any empty/blank screens, and instead of a crash
(FR-004, SC-003). Restore the correct documentId afterward.
