/**
 * assistant-ai — construção do prompt e chamada ao modelo Gemini.
 *
 * Modelo fixado em `gemini-3.1-flash-lite` (Research §2): esta versão não expõe
 * override por variável de ambiente, para remover qualquer caminho acidental
 * para um tier mais caro.
 *
 * Saída estruturada (Research §5): a chamada primária (`ask`) devolve
 * `{ answer, autoTranslated, onTopic, catalogSufficient, searchTopic }` via
 * responseMimeType/responseSchema, evitando parsing frágil de marcadores em
 * texto livre. Os dois últimos campos foram acrescentados por
 * specs/003-assistant-web-fallback (research.md §5) para permitir ao
 * controller decidir se vale a pena acionar `answerFromKnowledge` (abaixo) sem
 * uma segunda chamada de classificação.
 *
 * Fallback de conhecimento (specs/003): quando a pergunta é on-topic mas o
 * catálogo não chega, `answerFromKnowledge` faz uma segunda chamada normal ao
 * modelo — SEM pesquisa web / grounding (que exigiria billing) — deixando o
 * modelo responder a partir do seu conhecimento treinado, com o catálogo sempre
 * como fonte de maior prioridade.
 */

import { GoogleGenAI, Type } from '@google/genai';

import type { Catalog, CatalogField, CatalogItem } from './assistant-catalog';

const MODEL = 'gemini-3.1-flash-lite';

const LANGUAGE_NAMES: Record<string, string> = {
  pt: 'Portuguese (Portugal)',
  en: 'English',
  es: 'Spanish',
  fr: 'French',
};

export interface AssistantAnswer {
  answer: string;
  autoTranslated: boolean;
  onTopic: boolean;
  /** specs/003-assistant-web-fallback — true when `answer` is fully grounded in the catalog. */
  catalogSufficient: boolean;
  /** specs/003-assistant-web-fallback — short topic phrase, populated only when
   *  onTopic && !catalogSufficient; empty string otherwise. Never the visitor's raw wording.
   *  Used to focus the general-knowledge fallback call, not a search query. */
  searchTopic: string;
}

/** Esquema da resposta estruturada exigida ao modelo. */
const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    answer: {
      type: Type.STRING,
      description: "The reply to show the visitor, written in the visitor's active language.",
    },
    autoTranslated: {
      type: Type.BOOLEAN,
      description:
        'True only if the answer relied on catalog content marked [PT-ONLY] that you had to translate yourself.',
    },
    onTopic: {
      type: Type.BOOLEAN,
      description: 'True if the question was about the museum domain; false if it was declined as off-topic.',
    },
    catalogSufficient: {
      type: Type.BOOLEAN,
      description:
        'True when "answer" is fully grounded in the catalog below. False only when onTopic is true but the ' +
        'catalog had nothing relevant to answer the question (the case where you would otherwise say you don\'t ' +
        'have that information). Always true when onTopic is false.',
    },
    searchTopic: {
      type: Type.STRING,
      description:
        'A short restricted topic phrase (a few words, never the visitor\'s exact wording) describing what the ' +
        'question is actually about, populated only when onTopic is true and catalogSufficient is false. Empty ' +
        'string in every other case.',
    },
  },
  required: ['answer', 'autoTranslated', 'onTopic', 'catalogSufficient', 'searchTopic'],
  propertyOrdering: ['answer', 'autoTranslated', 'onTopic', 'catalogSufficient', 'searchTopic'],
};

/** Serializa um campo, assinalando o conteúdo que só existe em português. */
function renderField(label: string, field: CatalogField | null, indent = ''): string {
  if (!field) return '';
  const marker = field.official ? '' : ' [PT-ONLY]';
  return `${indent}${label}: ${field.value}${marker}\n`;
}

function renderItems(items: CatalogItem[], indent: string): string {
  let out = '';
  items.forEach((item) => {
    if (!item.name && !item.description) return;
    out += renderField('- Item', item.name, indent);
    out += renderField('  Description', item.description, indent);
  });
  return out;
}

/** Converte o catálogo em texto estruturado para o prompt de sistema. */
export function serializeCatalog(catalog: Catalog): string {
  let out = '';

  catalog.entities.forEach((entity) => {
    out += '=== MUSEUM ===\n';
    out += renderField('Name', entity.name);
    out += renderField('Description', entity.description);
    out += renderField('Welcome message', entity.welcomeMessage);

    if (entity.tours.length > 0) {
      out += '\n--- TOURS ---\n';
      entity.tours.forEach((tour) => {
        out += renderField('Tour', tour.name);
        out += renderField('  Duration', tour.duration);
        out += renderField('  Description', tour.description);
        if (tour.items.length > 0) {
          out += '  Stops on this tour:\n';
          out += renderItems(tour.items, '  ');
        }
        out += '\n';
      });
    }

    if (entity.maps.length > 0) {
      out += '\n--- MAPS, AREAS AND ITEMS ---\n';
      entity.maps.forEach((map) => {
        out += renderField('Map', map.name);
        out += renderField('  Floor', map.floor);
        map.areas.forEach((area) => {
          out += renderField('  Area', area.name);
          out += renderField('    Subtitle', area.subtitle);
          out += renderField('    Description', area.description);
          if (area.items.length > 0) {
            out += '    Items in this area:\n';
            out += renderItems(area.items, '    ');
          }
        });
        out += '\n';
      });
    }

    if (entity.dictionary.length > 0) {
      out += '\n--- INTERFACE TERMINOLOGY (labels used by the app, not museum facts) ---\n';
      entity.dictionary.forEach((entry) => {
        out += `${entry.key}: ${entry.value}\n`;
      });
    }
  });

  return out.trim();
}

/**
 * Instrução de sistema: definição do domínio do museu e recusa de perguntas fora
 * dele (FR-003, Research §4), regras de idioma/tradução (FR-004/FR-005/FR-006) e
 * proibição de inventar conteúdo fora do catálogo (FR-012).
 *
 * specs/003-assistant-web-fallback (spec.md Clarifications, 2026-07-27; FR-002,
 * FR-005): a fronteira on-topic/off-topic foi reformulada para favorecer
 * "on-topic" sempre que há uma ligação plausível ao museu — só se recusa
 * quando não há qualquer ligação plausível. O mesmo prompt também pede
 * catalogSufficient/searchTopic (FR-006), para o controller decidir se aciona
 * answerFromKnowledge() sem precisar de uma segunda chamada de classificação.
 */
export function buildSystemPrompt(catalog: Catalog, language: string): string {
  const languageName = LANGUAGE_NAMES[language] || LANGUAGE_NAMES.pt;
  const isBaseLanguage = language === 'pt';

  return `You are Museum Mate AI, the assistant of the museum described in the catalog below.

## Language
Always reply in ${languageName}. Never ask the visitor which language to use.

## What you talk about (museum domain)
Your domain is this museum and only this museum: the museum itself and its history, its
exhibits, areas, tours and items, and practical visit information (opening hours, location,
how to get around) when the catalog contains it. Questions about how to use this app to
visit the museum also count as in-domain.

Anything with NO plausible connection to this museum is OFF-TOPIC: general world knowledge,
other museums, news, weather, sport, politics, health, coding, maths, personal advice, or
requests to write, translate or role-play content unrelated to this museum. When a question's
connection to the museum is unclear rather than absent — it plausibly relates to the museum,
its history, its period, or its subject matter, even if not certain — treat it as IN-DOMAIN
rather than declining. Only decline when there is no plausible museum connection at all.

For an off-topic question, do NOT answer it — not even partially, not even if you know the
answer and it seems harmless. Instead reply briefly and politely that you can only help with
this museum, and redirect the visitor by pointing to something concrete they could ask about
(for example a tour, an area or an exhibit that actually appears in the catalog below). Set
"onTopic" to false for these replies.

If a question mixes both (e.g. "who painted this and what's the weather like?"), answer the
museum part normally from the catalog, then say plainly that you cannot help with the rest.
A mixed question counts as in-domain: set "onTopic" to true.

Note that "I don't have that information in the catalog" is NOT an off-topic decline: a
museum question the catalog cannot answer is still on-topic — set "onTopic" to true.

## Using the catalog
The catalog below is your ONLY source of truth about the museum.
- Answer strictly from it. Never add facts from general world knowledge, and never invent names, dates, locations or descriptions.
- If the catalog contains nothing relevant to a museum question, say plainly that you do not have that information. Do not guess.
- The catalog covers the WHOLE museum. Answer about any tour, area or item in it, regardless of what the visitor may be looking at in the app.

## Catalog sufficiency and search topic
Independently of "onTopic", report whether the catalog actually gave you enough to answer:
- Set "catalogSufficient" to true whenever "answer" is fully grounded in the catalog above — this includes every off-topic decline (onTopic: false), which always has "catalogSufficient" set to true and "searchTopic" left as an empty string, since those fields don't apply to declines.
- Set "catalogSufficient" to false only when "onTopic" is true but the catalog had nothing relevant to answer the question — exactly the case where "answer" says you don't have that information.
- When, and only when, "catalogSufficient" is false, also set "searchTopic" to a short phrase (a handful of words) naming what the question is actually about — for example "founding date of the museum building", not the visitor's exact wording. This never repeats the visitor's raw question text. In every other case, leave "searchTopic" as an empty string.

## Translation rules
${
  isBaseLanguage
    ? `The catalog is already in ${languageName}. Always set "autoTranslated" to false.`
    : `Catalog text WITHOUT a marker is the museum's official ${languageName} translation: reuse that wording as-is and do not re-translate or paraphrase it unnecessarily.
Catalog text marked [PT-ONLY] exists only in Portuguese: translate it into ${languageName} yourself.
The [PT-ONLY] marker is internal — never show it or mention it to the visitor.
Set "autoTranslated" to true if, and only if, your answer relied on [PT-ONLY] content that you translated. If everything you used was already official ${languageName} text, set it to false.`
}

## Answer style
Be concise, warm and helpful — a few sentences is usually enough. Plain text only, no markdown.

## CATALOG
${serializeCatalog(catalog)}`;
}

/**
 * specs/003-assistant-web-fallback — resultado da chamada de fallback de
 * conhecimento. `confident: false` cobre "o modelo não tem confiança suficiente
 * para responder" — nesse caso o controller trata como se não houvesse resposta
 * (FR-009), devolvendo o "não tenho essa informação" da chamada primária.
 */
export interface KnowledgeAnswer {
  answer: string;
  confident: boolean;
}

/** Esquema da resposta estruturada da chamada de fallback de conhecimento. */
const KNOWLEDGE_RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    answer: {
      type: Type.STRING,
      description:
        "The reply to show the visitor, written in the visitor's active language. Only meaningful when " +
        '"confident" is true.',
    },
    confident: {
      type: Type.BOOLEAN,
      description:
        'True only if you are confident enough in a specific, reliable answer to show it. False if you ' +
        'are unsure, would have to guess, or have no reliable answer — never fabricate to fill the gap.',
    },
  },
  required: ['answer', 'confident'],
  propertyOrdering: ['answer', 'confident'],
};

/**
 * Instrução de sistema da chamada de fallback de conhecimento (FR-006, FR-008,
 * research.md §4/§7): o modelo pode complementar com o seu conhecimento geral,
 * mas SÓ para aquilo que o catálogo não cobre, nunca contradizendo o catálogo, e
 * assumindo que não sabe sempre que não tiver confiança suficiente (nunca
 * inventar). `searchTopic` foca a resposta no que a pergunta é realmente sobre.
 */
function buildKnowledgeFallbackSystemPrompt(museumName: string, language: string, searchTopic: string, catalog: Catalog): string {
  const languageName = LANGUAGE_NAMES[language] || LANGUAGE_NAMES.pt;

  return `You are Museum Mate AI, the assistant of "${museumName}". The visitor asked a question that is about this
museum but that its own catalog could not fully answer on its own. You may now draw on your own general
knowledge to try to help — but under strict rules.

## Topic focus
The question is specifically about: ${searchTopic}. Stay on that, in connection with "${museumName}".
Do not drift to unrelated general-knowledge topics even if the visitor's exact phrasing suggests a
broader subject.

## The catalog is always authoritative (FR-008 — do not skip this)
The museum's own catalog is included below and is ALWAYS the source of highest priority. If anything in
your general knowledge conflicts with a fact already stated in the catalog, the catalog wins — use the
catalog's version and never contradict it. Only use your own knowledge to fill in details the catalog
genuinely does not cover, never to "correct" or second-guess something the catalog already states.

## Only answer when confident (FR-009 — do not invent)
Answer from your general knowledge only when you are genuinely confident it is accurate. If you are not
sure, if you would have to guess, or if you have no reliable answer, set "confident" to false and do not
fabricate anything to fill the gap. A truthful "I don't know" is always better than a confident-sounding
invention.

## Answering
Reply in ${languageName}. Be concise — a few sentences is usually enough. Plain text only, no markdown.
Set "confident" to true only when you are giving a specific, reliable answer within the focus above.

## CATALOG
${serializeCatalog(catalog)}`;
}

let client: GoogleGenAI | null = null;

function getClient(): GoogleGenAI {
  if (!client) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not set in the environment');
    }
    client = new GoogleGenAI({ apiKey });
  }
  return client;
}

/**
 * specs/003-assistant-web-fallback — chamada de fallback de conhecimento,
 * acionada pelo controller apenas quando a chamada primária classifica a
 * pergunta como on-topic mas com catálogo insuficiente (catalogSufficient ===
 * false).
 *
 * É uma chamada normal ao modelo, SEM ferramenta de pesquisa/grounding (que
 * exigiria billing, research.md §1/§2): o modelo responde a partir do seu
 * conhecimento treinado, com o catálogo no prompt como fonte de maior
 * prioridade e a obrigação de assumir que não sabe quando não tem confiança.
 */
async function callGeminiKnowledge({
  museumName,
  message,
  language,
  searchTopic,
  catalog,
}: {
  museumName: string;
  message: string;
  language: string;
  searchTopic: string;
  catalog: Catalog;
}): Promise<KnowledgeAnswer> {
  const response = await getClient().models.generateContent({
    model: MODEL,
    contents: [{ role: 'user', parts: [{ text: message }] }],
    config: {
      systemInstruction: buildKnowledgeFallbackSystemPrompt(museumName, language, searchTopic, catalog),
      responseMimeType: 'application/json',
      responseSchema: KNOWLEDGE_RESPONSE_SCHEMA,
      temperature: 0.2,
    },
  });

  const raw = response.text;
  if (!raw) {
    throw new Error('Gemini returned an empty response for answerFromKnowledge');
  }

  const parsed = JSON.parse(raw);

  return {
    answer: typeof parsed.answer === 'string' ? parsed.answer.trim() : '',
    confident: parsed.confident === true,
  };
}

export default ({ strapi }) => ({
  /**
   * Chama o Gemini com o catálogo, o histórico da sessão e a pergunta atual.
   * Lança em caso de falha de rede/API ou de resposta não-parseável — o controller
   * traduz isso para 502/504.
   */
  async ask({
    catalog,
    message,
    language,
    history,
  }: {
    catalog: Catalog;
    message: string;
    language: string;
    history: Array<{ role: string; text: string }>;
  }): Promise<AssistantAnswer> {
    // Histórico da sessão como turnos anteriores reais da conversa (FR-014),
    // do mais antigo para o mais recente, antes da pergunta atual.
    const contents = (history || []).map((turn) => ({
      role: turn.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: turn.text }],
    }));

    contents.push({ role: 'user', parts: [{ text: message }] });

    const response = await getClient().models.generateContent({
      model: MODEL,
      contents,
      config: {
        systemInstruction: buildSystemPrompt(catalog, language),
        responseMimeType: 'application/json',
        responseSchema: RESPONSE_SCHEMA,
        temperature: 0.3,
      },
    });

    const raw = response.text;
    if (!raw) {
      throw new Error('Gemini returned an empty response');
    }

    const parsed = JSON.parse(raw);

    if (typeof parsed.answer !== 'string' || parsed.answer.trim().length === 0) {
      throw new Error('Gemini response did not contain a usable "answer" field');
    }

    const onTopic = parsed.onTopic !== false;

    return {
      answer: parsed.answer.trim(),
      autoTranslated: parsed.autoTranslated === true,
      // Ausente => assume-se on-topic, para nunca marcar como recusa uma resposta válida.
      onTopic,
      // specs/003-assistant-web-fallback: ausente/off-topic => assume-se catálogo suficiente,
      // para nunca acionar answerFromKnowledge() por engano numa recusa fora de âmbito.
      catalogSufficient: !onTopic || parsed.catalogSufficient !== false,
      searchTopic: onTopic && parsed.catalogSufficient === false && typeof parsed.searchTopic === 'string'
        ? parsed.searchTopic.trim()
        : '',
    };
  },

  /**
   * specs/003-assistant-web-fallback — fallback de conhecimento (FR-003,
   * FR-006). Chamado pelo controller só quando a chamada `ask()` acima
   * classifica a pergunta como on-topic mas com catálogo insuficiente.
   * Lança em caso de falha de rede/API — o controller trata isso como
   * inconclusivo (FR-009), tal como um `confident: false` devolvido aqui.
   */
  async answerFromKnowledge({
    catalog,
    message,
    language,
    searchTopic,
  }: {
    catalog: Catalog;
    message: string;
    language: string;
    searchTopic: string;
  }): Promise<KnowledgeAnswer> {
    const museumName = catalog.entities[0] && catalog.entities[0].name ? catalog.entities[0].name.value : '';

    return callGeminiKnowledge({ museumName, message, language, searchTopic, catalog });
  },
});
