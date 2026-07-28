/**
 * Follow-up to fix-dictionary-split.js: documents().delete({ documentId })
 * without an explicit locale only removed the pt variant of each old split
 * document, leaving its en/es/fr variants behind as orphaned duplicates
 * (still linked to the ficticio entity, with no pt sibling anymore). This
 * finds those leftovers -- any en/es/fr Dictionary document linked to the
 * ficticio entity that has no corresponding pt document under the same
 * documentId -- and deletes them explicitly, per locale.
 *
 * Must be run with the Strapi dev server stopped (same reason as the other
 * scripts in this folder).
 *
 *   node scripts/fix-dictionary-cleanup-leftovers.js
 */

const strapiFactory = require('@strapi/strapi');

const FICTICIO_DOC_ID = 'gqag59gr2pvu95qawb4dq1ol';
const CHECK_LOCALES = ['en', 'es', 'fr'];

async function main() {
  const appContext = await strapiFactory.compileStrapi();
  const app = await strapiFactory.createStrapi(appContext).load();

  let deleted = 0;
  const failures = [];

  try {
    const ptDocIds = new Set(
      (
        await app.documents('api::dictionary.dictionary').findMany({
          locale: 'pt',
          status: 'published',
          populate: { entity: true },
        })
      )
        .filter((e) => e.entity?.documentId === FICTICIO_DOC_ID)
        .map((e) => e.documentId)
    );

    for (const locale of CHECK_LOCALES) {
      const entries = await app.documents('api::dictionary.dictionary').findMany({
        locale,
        status: 'published',
        populate: { entity: true },
      });

      const leftovers = entries.filter(
        (e) => e.entity?.documentId === FICTICIO_DOC_ID && !ptDocIds.has(e.documentId)
      );

      console.log(`${locale}: ${leftovers.length} leftover document(s) to delete.`);

      for (const entry of leftovers) {
        try {
          await app.documents('api::dictionary.dictionary').delete({ documentId: entry.documentId, locale });
          console.log(`  [ok] deleted ${entry.documentId} (${locale}, "${entry.key}")`);
          deleted++;
        } catch (err) {
          console.error(`  [FAIL] ${entry.documentId} (${locale}): ${err.message}`);
          failures.push({ documentId: entry.documentId, locale, error: err.message });
        }
      }
    }

    console.log(`\nDone. Deleted ${deleted} leftover document(s).`);
    if (failures.length > 0) {
      console.log(`${failures.length} failure(s):`);
      for (const f of failures) console.log(`  ${f.documentId} (${f.locale}): ${f.error}`);
    }
  } finally {
    await app.destroy();
  }

  if (failures.length > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
