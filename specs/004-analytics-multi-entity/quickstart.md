# Quickstart: Validating Multi-Museum Analytics Segmentation

## Prerequisites

- Strapi backend running locally (`npm run develop` in `backend/app/`) with
  both `entidade` documents present: the original fictional museum
  (documentId `gqag59gr2pvu95qawb4dq1ol`) and Museu de Portimão
  (`ifajyzfd52v3tvq1mrf8j6eu`).
- The Strapi dev server **stopped** for the one-time backfill script run
  (SQLite allows one writer), then restarted afterward.
- Mobile app buildable/runnable, so it can generate real `visit_start` /
  `item_view` / `scan_success` events against each museum in turn.
- Access to the Strapi admin panel (`analytics-dashboard` plugin page).

## Scenario 1 — Schema change + backfill, no data lost

1. Add `entidadeDocumentId` to the `analytics-event` schema (contracts/event-attribution.md).
2. Regenerate types (`npm run develop` once, or `strapi ts:generate-types`), stop the server.
3. Note the total row count of `analytics-event` (e.g. via the admin content
   manager or a direct query) before running the backfill.
4. Run `node scripts/backfill-analytics-entity.js` (research.md §9).
5. Confirm: total row count is unchanged, and every row now has
   `entidadeDocumentId = 'gqag59gr2pvu95qawb4dq1ol'`.

**Expected**: SC-002 — no pre-existing event is lost or left unattributed.

## Scenario 2 — New events carry the right museum (US1)

1. Restart the backend with `ACTIVE_ENTITY_DOCUMENT_ID` set to Museu de
   Portimão in both `config/museum.ts` and `ApiHandler.js`.
2. From the app: start a visit, view an item, scan a code.
3. Ask the in-app assistant one on-topic question (answerable from the
   catalog) and, if reachable, one off-domain question.
4. Inspect the new `analytics-event` rows (admin content manager or a direct
   `GET /api/analytics-events?sort=id:desc&pagination[pageSize]=10`).

**Expected**: every new row — both the visitor events and the two assistant
events — carries `entidadeDocumentId = 'ifajyzfd52v3tvq1mrf8j6eu'` (SC-001).

## Scenario 3 — Dashboard opens on the active museum and stays scoped (US2)

1. Open the `analytics-dashboard` plugin page in the Strapi admin.
2. Confirm the museum selector defaults to Museu de Portimão (FR-017) — no
   manual selection needed.
3. Confirm the KPIs, tables and charts reflect only Portimão's events from
   Scenario 2 (not the fictional museum's history).
4. Switch the selector to the fictional museum.
5. Confirm every figure changes to that museum's own history, within ~3
   seconds and without a page reload (SC-004).
6. Switch the active time period (today / 7d / 30d / year) with a museum
   selected → confirm the museum selection is preserved (Acceptance Scenario
   US2.2).
7. Wait for one automatic refresh cycle (10s) → confirm the selection is not
   reset and only the selected museum's events are re-fetched (open the
   browser's network tab and check the request's `filters[entidadeDocumentId]`
   query param).

**Expected**: SC-003 — 0 cross-museum contamination in any figure, verified by
switching and comparing.

## Scenario 4 — Item names resolve correctly for the selected museum (US2)

1. With Museu de Portimão selected, open the "Itens Mais Vistos" chart.
2. Confirm every item shown displays its real name — none as
   `Item #<id>`.
3. Repeat with the fictional museum selected.

**Expected**: SC-006 — 100% of the selected museum's items resolve to real
names, regardless of the combined item count across both museums.

## Scenario 5 — Assistant metrics (US3)

1. With Museu de Portimão selected and the same period as Scenario 2, locate
   the new assistant-usage section on the dashboard.
2. Confirm it shows (at least) four distinct figures: answered, off-domain
   refusals, technical failures, general-knowledge fallback used.
3. Ask the assistant a question that is answerable only from the model's
   general knowledge (not the catalog) and refresh the dashboard.
4. Confirm the fallback figure increments, distinct from "answered".

**Expected**: SC-007 — four independently readable figures; SC-008 — an
administrator can tell "off-topic questions" apart from "assistant is
failing" from the dashboard alone.

## Scenario 6 — Environment discipline fix (FR-014)

1. With the browser's network tab open on the dashboard page, confirm every
   request goes to a relative path (i.e., the same origin the admin panel is
   served from), never a literal `http://localhost:1337`.
2. Confirm `GET /analytics-events/language-stats` now returns 404 (FR-010 —
   endpoint removed).

**Expected**: no hardcoded host remains in `HomePage.jsx`; the removed
endpoint is gone, not merely unused.
