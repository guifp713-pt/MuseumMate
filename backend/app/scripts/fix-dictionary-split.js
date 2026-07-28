/**
 * One-off fix for the Dictionary content type: 35 documentIds had their locale
 * variants split across two entities (pt -> Museu de Portimao, en/es/fr ->
 * entidade ficticia) instead of each entity having its own complete pt+en+es+fr
 * set. Root cause: when Portimao's Dictionary content was seeded, the pt rows'
 * `entity` relation was repointed from the ficticia entity to Portimao, but the
 * pre-existing en/es/fr rows for those same documentIds were left untouched,
 * still linked to the ficticia entity -- leaving the ficticia entity with 0 pt
 * rows and Portimao with 0 en/es/fr rows.
 *
 * This creates two fully independent documents per key (one per entity, all
 * four locales, values reused from whichever side already had them -- no new
 * translation needed, this is generic reused UI-chrome text), then deletes the
 * old split document.
 *
 * Must be run with the Strapi dev server stopped (same reason as
 * translate-content.js: boots its own instance, sqlite only allows one writer).
 *
 *   node scripts/fix-dictionary-split.js
 */

const strapiFactory = require('@strapi/strapi');

const FICTICIO_DOC_ID = 'gqag59gr2pvu95qawb4dq1ol';
const PORTIMAO_DOC_ID = 'ifajyzfd52v3tvq1mrf8j6eu';
const LOCALES = ['pt', 'en', 'es', 'fr'];

async function createFullDocument(strapi, entityDocId, key, valuesByLocale) {
  const available = LOCALES.filter((l) => valuesByLocale[l] != null);
  const [firstLocale, ...restLocales] = available;

  const created = await strapi.documents('api::dictionary.dictionary').create({
    locale: firstLocale,
    data: {
      key,
      value: valuesByLocale[firstLocale],
      entity: { connect: [{ documentId: entityDocId }] },
    },
    status: 'published',
  });

  for (const locale of restLocales) {
    await strapi.documents('api::dictionary.dictionary').update({
      documentId: created.documentId,
      locale,
      data: {
        key,
        value: valuesByLocale[locale],
        entity: { connect: [{ documentId: entityDocId }] },
      },
      status: 'published',
    });
  }

  return created.documentId;
}

async function main() {
  const appContext = await strapiFactory.compileStrapi();
  const app = await strapiFactory.createStrapi(appContext).load();

  const failures = [];
  let fixed = 0;
  let splitDocsCount = 0;

  try {
    // The split documents are the ones whose pt row is linked to Portimao --
    // that's the half of the split that's "wrong" relative to the original
    // ficticio-owned document.
    const ptEntries = await app.documents('api::dictionary.dictionary').findMany({
      locale: 'pt',
      status: 'published',
      populate: { entity: true },
    });

    const splitDocs = ptEntries.filter((e) => e.entity?.documentId === PORTIMAO_DOC_ID);
    splitDocsCount = splitDocs.length;
    console.log(`Found ${splitDocs.length} split Dictionary document(s) to fix.`);

    for (const ptEntry of splitDocs) {
      const oldDocId = ptEntry.documentId;
      const key = ptEntry.key;

      try {
        const [enEntry, esEntry, frEntry] = await Promise.all([
          app.documents('api::dictionary.dictionary').findOne({ documentId: oldDocId, locale: 'en', status: 'published' }),
          app.documents('api::dictionary.dictionary').findOne({ documentId: oldDocId, locale: 'es', status: 'published' }),
          app.documents('api::dictionary.dictionary').findOne({ documentId: oldDocId, locale: 'fr', status: 'published' }),
        ]);

        if (!enEntry || !esEntry || !frEntry) {
          console.error(`  [SKIP] ${oldDocId} (${key}): missing en/es/fr source under the old documentId, not touching.`);
          continue;
        }

        const values = { pt: ptEntry.value, en: enEntry.value, es: esEntry.value, fr: frEntry.value };

        const newFicticioDocId = await createFullDocument(app, FICTICIO_DOC_ID, key, values);
        const newPortimaoDocId = await createFullDocument(app, PORTIMAO_DOC_ID, key, values);

        await app.documents('api::dictionary.dictionary').delete({ documentId: oldDocId });

        console.log(`  [ok] "${key}": old ${oldDocId} -> ficticio ${newFicticioDocId}, portimao ${newPortimaoDocId}`);
        fixed++;
      } catch (err) {
        console.error(`  [FAIL] ${oldDocId} (${key}): ${err.message}`);
        failures.push({ oldDocId, key, error: err.message });
      }
    }

    console.log(`\nDone. Fixed ${fixed}/${splitDocsCount}.`);
    if (failures.length > 0) {
      console.log(`${failures.length} failure(s):`);
      for (const f of failures) console.log(`  ${f.oldDocId} (${f.key}): ${f.error}`);
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
