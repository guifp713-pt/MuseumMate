/**
 * Creates EN/ES/FR localizations for every Portuguese entry, mirroring what an
 * editor gets from clicking "Create locale" in the Strapi admin for each
 * content type: same document, same relations, same media, same draft/publish
 * state -- only the human-language text fields are replaced, via Gemini.
 *
 * Must be run with the Strapi dev server stopped (it boots its own instance,
 * same as `strapi console`, and sqlite only allows one writer at a time).
 *
 *   node scripts/translate-content.js          # skip locales that already exist
 *   node scripts/translate-content.js --force  # re-translate & overwrite existing locales
 */

const strapiFactory = require('@strapi/strapi');
const { GoogleGenAI, Type } = require('@google/genai');

const TARGET_LOCALES = ['en', 'es', 'fr'];
const LANGUAGE_NAMES = { en: 'English', es: 'Spanish', fr: 'French' };
const MODEL = 'gemini-3.1-flash-lite';
const FORCE = process.argv.includes('--force');

const NEW_LOCALES = [
  { code: 'en', name: 'English (en)' },
  { code: 'es', name: 'Spanish (es)' },
  { code: 'fr', name: 'French (fr)' },
];
const STALE_LOCALES = ['es-ES', 'fr-FR'];

// Order matters: each type's relations point at documents created earlier in this list.
const CONTENT_TYPES = [
  {
    uid: 'api::entidade.entidade',
    label: 'Entity',
    translate: ['nameEntity', 'descriptionEntity', 'welcome_message'],
    copyMedia: ['imageEntity'], // audio intentionally left empty (no translated narration yet)
    copyVerbatim: [],
    relations: [],
  },
  {
    uid: 'api::map.map',
    label: 'Map',
    translate: ['nameMap', 'floorMap'],
    copyMedia: ['imageMap'],
    copyVerbatim: [],
    relations: [{ field: 'entidade', many: false }],
  },
  {
    uid: 'api::area.area',
    label: 'Area',
    translate: ['nameArea', 'subtitleArea', 'descriptionArea'],
    copyMedia: ['imageArea'], // audioArea intentionally left empty
    copyVerbatim: ['posX', 'posY', 'SelectorPin'],
    relations: [{ field: 'map', many: false }],
  },
  {
    uid: 'api::item.item',
    label: 'Item',
    translate: ['nameItem', 'descriptionItem'],
    copyMedia: ['coverItem', 'mediaItem', 'qrCodeImage'], // audioItem intentionally left empty
    copyVerbatim: ['posXItem', 'posYItem', 'SelectorPinItem', 'code'],
    relations: [{ field: 'area', many: false }],
  },
  {
    uid: 'api::tour.tour',
    label: 'Tour',
    translate: ['nameTour', 'timeTour', 'descriptionTour'],
    copyMedia: ['imageTour'],
    copyVerbatim: [],
    relations: [
      { field: 'entidade', many: false },
      { field: 'items', many: true },
      { field: 'maps', many: true },
    ],
  },
  {
    uid: 'api::dictionary.dictionary',
    label: 'Dictionary',
    translate: ['value'],
    copyMedia: [],
    copyVerbatim: ['key'], // key is a lookup id shared across locales, never translated
    relations: [{ field: 'entity', many: false }],
  },
];

let genaiClient;
function getClient() {
  if (!genaiClient) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY is not set in the environment');
    genaiClient = new GoogleGenAI({ apiKey });
  }
  return genaiClient;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Reads the `retryDelay` the API suggests out of a Gemini ApiError, falling back to 60s. */
function extractRetryDelayMs(err) {
  try {
    const body = JSON.parse(err.message);
    const detail = (body?.error?.details || []).find((d) => (d['@type'] || '').includes('RetryInfo'));
    const seconds = detail?.retryDelay ? parseFloat(detail.retryDelay) : NaN;
    if (!Number.isNaN(seconds)) return Math.ceil(seconds * 1000) + 1000;
  } catch (_err) {
    /* fall through to default */
  }
  return 60000;
}

/** Retries Gemini calls on free-tier rate limiting (429 / RESOURCE_EXHAUSTED), honoring the suggested retryDelay. */
async function generateWithRetry(params, maxAttempts = 5) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await getClient().models.generateContent(params);
    } catch (err) {
      const isRateLimit = err.status === 429 || /RESOURCE_EXHAUSTED/.test(err.message || '');
      if (!isRateLimit || attempt === maxAttempts) throw err;
      const delayMs = extractRetryDelayMs(err);
      console.log(`  Rate limited by Gemini, waiting ${Math.round(delayMs / 1000)}s (attempt ${attempt}/${maxAttempts})...`);
      await sleep(delayMs);
    }
  }
}

/** Translates a flat array of strings, preserving order/length; empty strings pass through untouched. */
async function translateBatch(strings, targetLocale, contextLabel) {
  const nonEmpty = strings.map((s, i) => ({ i, s })).filter((x) => typeof x.s === 'string' && x.s.trim().length > 0);
  if (nonEmpty.length === 0) return strings.map(() => '');

  const languageName = LANGUAGE_NAMES[targetLocale];
  const response = await generateWithRetry({
    model: MODEL,
    contents: [{ role: 'user', parts: [{ text: JSON.stringify(nonEmpty.map((x) => x.s)) }] }],
    config: {
      systemInstruction: `You are translating museum exhibit copy (${contextLabel}) from Portuguese (Portugal) to ${languageName}.
Translate each string in the JSON array. Return a JSON array of the same length and in the same order, containing ONLY the ${languageName} translations, nothing else.
Keep proper names of people, places and artworks as-is unless they have a well-established ${languageName} form. Preserve numbers, units and punctuation style. Do not add commentary or notes.`,
      responseMimeType: 'application/json',
      responseSchema: { type: Type.ARRAY, items: { type: Type.STRING } },
      temperature: 0.2,
    },
  });
  await sleep(4500); // stay comfortably under the free-tier 15 requests/minute cap

  const raw = response.text;
  if (!raw) throw new Error(`Gemini returned an empty response translating ${contextLabel} to ${targetLocale}`);

  const arr = JSON.parse(raw);
  if (!Array.isArray(arr) || arr.length !== nonEmpty.length) {
    const got = Array.isArray(arr) ? arr.length : typeof arr;
    throw new Error(`Gemini returned ${got} items, expected ${nonEmpty.length}, for ${contextLabel}/${targetLocale}`);
  }

  const result = strings.map(() => '');
  nonEmpty.forEach((x, k) => {
    result[x.i] = arr[k];
  });
  return result;
}

async function ensureLocales(strapi) {
  const localeService = strapi.plugin('i18n').service('locales');
  const existing = await localeService.find();
  const byCode = new Map(existing.map((l) => [l.code, l]));

  for (const code of STALE_LOCALES) {
    const locale = byCode.get(code);
    if (locale) {
      await localeService.delete({ id: locale.id });
      console.log(`Removed unused locale ${code}`);
    }
  }

  for (const { code, name } of NEW_LOCALES) {
    if (!byCode.has(code)) {
      await localeService.create({ code, name });
      console.log(`Created locale ${code}`);
    }
  }
}

function buildPopulate(config) {
  const populate = {};
  for (const field of config.copyMedia) populate[field] = true;
  for (const rel of config.relations) populate[rel.field] = true;
  return populate;
}

/** Merges pt draft + published entries per documentId; published wins as the translation source. */
async function fetchPtSources(strapi, uid, populate) {
  const [published, drafts] = await Promise.all([
    strapi.documents(uid).findMany({ locale: 'pt', status: 'published', populate }),
    strapi.documents(uid).findMany({ locale: 'pt', status: 'draft', populate }),
  ]);

  const byDocumentId = new Map();
  for (const entry of drafts) byDocumentId.set(entry.documentId, { entry, hasPublished: false });
  for (const entry of published) byDocumentId.set(entry.documentId, { entry, hasPublished: true });
  return [...byDocumentId.values()];
}

function buildRelationData(config, entry) {
  const data = {};
  for (const rel of config.relations) {
    const value = entry[rel.field];
    if (rel.many) {
      data[rel.field] = { connect: (value || []).map((v) => ({ documentId: v.documentId })) };
    } else if (value) {
      data[rel.field] = { connect: [{ documentId: value.documentId }] };
    }
  }
  return data;
}

function buildMediaData(config, entry) {
  const data = {};
  for (const field of config.copyMedia) {
    const value = entry[field];
    if (Array.isArray(value)) data[field] = value.map((v) => v.id);
    else if (value) data[field] = value.id;
  }
  return data;
}

async function processContentType(strapi, config) {
  const populate = buildPopulate(config);
  const sources = await fetchPtSources(strapi, config.uid, populate);
  console.log(`\n${config.label} (${config.uid}): ${sources.length} Portuguese document(s)`);

  // Pre-check what already exists so reruns don't burn Gemini quota re-translating
  // content that's just going to be skipped below anyway.
  const needsLocale = {};
  for (const locale of TARGET_LOCALES) {
    if (FORCE) {
      needsLocale[locale] = true;
      continue;
    }
    let anyMissing = false;
    for (const { entry } of sources) {
      const existing = await strapi.documents(config.uid).findOne({
        documentId: entry.documentId,
        locale,
        status: 'draft',
      });
      if (!existing) {
        anyMissing = true;
        break;
      }
    }
    needsLocale[locale] = anyMissing;
  }

  const translationsByLocale = {};
  for (const locale of TARGET_LOCALES) {
    if (config.translate.length === 0 || !needsLocale[locale]) {
      translationsByLocale[locale] = [];
      continue;
    }
    const flat = [];
    for (const { entry } of sources) {
      for (const field of config.translate) flat.push(entry[field] || '');
    }
    translationsByLocale[locale] = await translateBatch(flat, locale, config.label);
  }

  for (const locale of TARGET_LOCALES) {
    if (!needsLocale[locale]) console.log(`  [skip] all ${config.label} entries already have ${locale}`);
  }

  const failures = [];
  const activeLocales = TARGET_LOCALES.filter((locale) => needsLocale[locale]);

  for (let i = 0; i < sources.length; i++) {
    const { entry, hasPublished } = sources[i];

    for (const locale of activeLocales) {
      try {
        if (!FORCE) {
          const existing = await strapi.documents(config.uid).findOne({
            documentId: entry.documentId,
            locale,
            status: 'draft',
          });
          if (existing) {
            console.log(`  [skip] ${entry.documentId} already has ${locale}`);
            continue;
          }
        }

        const data = {};
        config.translate.forEach((field, fIdx) => {
          data[field] = translationsByLocale[locale][i * config.translate.length + fIdx];
        });
        for (const field of config.copyVerbatim) data[field] = entry[field];
        Object.assign(data, buildMediaData(config, entry));
        Object.assign(data, buildRelationData(config, entry));

        await strapi.documents(config.uid).update({
          documentId: entry.documentId,
          locale,
          data,
          status: hasPublished ? 'published' : 'draft',
        });

        console.log(`  [ok] ${entry.documentId} -> ${locale}${hasPublished ? ' (published)' : ' (draft)'}`);
      } catch (err) {
        console.error(`  [FAIL] ${entry.documentId} -> ${locale}: ${err.message}`);
        failures.push({ uid: config.uid, documentId: entry.documentId, locale, error: err.message });
      }
    }
  }

  return failures;
}

async function main() {
  const appContext = await strapiFactory.compileStrapi();
  const app = await strapiFactory.createStrapi(appContext).load();

  const allFailures = [];
  try {
    await ensureLocales(app);

    for (const config of CONTENT_TYPES) {
      const failures = await processContentType(app, config);
      allFailures.push(...failures);
    }

    console.log('\nDone.');
    if (allFailures.length > 0) {
      console.log(`\n${allFailures.length} failure(s):`);
      for (const f of allFailures) {
        console.log(`  ${f.uid} ${f.documentId} -> ${f.locale}: ${f.error}`);
      }
    }
  } finally {
    await app.destroy();
  }

  if (allFailures.length > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
