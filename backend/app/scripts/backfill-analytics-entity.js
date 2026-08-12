/**
 * One-off backfill for specs/004-analytics-multi-entity (FR-005).
 *
 * Labels every pre-existing `analytics-event` row that has no `entidadeDocumentId`
 * (i.e. every row created before this feature's schema change) with the
 * documentId of the original fictional museum — it was the only museum in
 * existence while those rows were produced. New rows created after the schema
 * change are already stamped at write time by both producers
 * (AnalyticsHandler.js, assistant.ts) and are left untouched by this script.
 *
 * Must be run with the Strapi dev server stopped (it boots its own instance,
 * same as `strapi console`, and sqlite only allows one writer at a time).
 *
 *   node scripts/backfill-analytics-entity.js
 */

const strapiFactory = require('@strapi/strapi');

const ANALYTICS_EVENT_UID = 'api::analytics-event.analytics-event';
const FICTIONAL_ENTITY_DOCUMENT_ID = 'gqag59gr2pvu95qawb4dq1ol'; // "Industria Textil do Norte"

async function main() {
  const appContext = await strapiFactory.compileStrapi();
  const app = await strapiFactory.createStrapi(appContext).load();

  try {
    const totalBefore = await app.db.query(ANALYTICS_EVENT_UID).count();

    const { count: updated } = await app.db.query(ANALYTICS_EVENT_UID).updateMany({
      where: {
        $or: [{ entidadeDocumentId: null }, { entidadeDocumentId: '' }],
      },
      data: {
        entidadeDocumentId: FICTIONAL_ENTITY_DOCUMENT_ID,
      },
    });

    const totalAfter = await app.db.query(ANALYTICS_EVENT_UID).count();
    const stillUnattributed = await app.db.query(ANALYTICS_EVENT_UID).count({
      where: {
        $or: [{ entidadeDocumentId: null }, { entidadeDocumentId: '' }],
      },
    });

    console.log(`Rows before: ${totalBefore}`);
    console.log(`Rows updated: ${updated}`);
    console.log(`Rows after: ${totalAfter}`);
    console.log(`Still unattributed after backfill: ${stillUnattributed}`);

    if (totalBefore !== totalAfter) {
      throw new Error(
        `Row count changed during backfill (${totalBefore} -> ${totalAfter}) — this script must never delete or create rows.`
      );
    }
    if (stillUnattributed !== 0) {
      throw new Error(`${stillUnattributed} row(s) remain unattributed after backfill.`);
    }

    console.log('\nDone.');
  } finally {
    await app.destroy();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
