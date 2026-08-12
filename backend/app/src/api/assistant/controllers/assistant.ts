/**
 * Assistant controller — POST /api/assistant/ask
 *
 * Não existe content-type `assistant`: este é um controller custom puro,
 * seguindo o contrato em specs/001-ai-museum-assistant/contracts/assistant-api.md
 * (estendido por specs/003-assistant-web-fallback/contracts/assistant-api-web-fallback.md)
 */

import { KNOWLEDGE_FALLBACK_ENABLED } from '../../../config/assistant';
import { ACTIVE_ENTITY_DOCUMENT_ID } from '../../../config/museum';

const SUPPORTED_LANGUAGES = ['pt', 'en', 'es', 'fr'];
const MAX_MESSAGE_LENGTH = 2000;
const MAX_HISTORY_TURNS = 20;

/**
 * Timeout do lado do servidor para a chamada ao Gemini (Research §7).
 * Deliberadamente mais curto que o timeout do cliente (13s), para que o backend
 * ganhe a corrida e consiga devolver um 504 estruturado (e registar analytics)
 * antes de o cliente desistir com um erro de rede genérico.
 *
 * Histórico: 6s → 10s → 20s. O valor de 10s produzia 504s reais em runtime.
 *
 * Medições (2026-07-21, mesma pergunta/prompt/resposta, 4 execuções): 6.5s,
 * 7.3s, 7.5s, 9.3s — quase 3s de dispersão sem nada variar do nosso lado. Uma
 * resposta de 897 chars demorou 4.9s, menos que uma de 192 chars. A cauda é
 * variância do provider, não tamanho de prompt nem de resposta, por isso o
 * timeout tem de ter folga sobre o pior caso observado em vez de o roçar.
 *
 * specs/003-assistant-web-fallback: a segunda chamada (answerFromKnowledge)
 * reutiliza este mesmo timeout — é uma chamada normal ao modelo, sem pesquisa
 * web, com o mesmo perfil de latência da primária, por isso não precisa de um
 * timeout próprio. No pior caso um pedido que passa pelas duas chamadas soma
 * 2×AI_TIMEOUT_MS (~40s); o timeout do cliente (REQUEST_TIMEOUT_MS,
 * AssistantHandler.js) fica acima disso para o backend ganhar sempre a corrida.
 */
const AI_TIMEOUT_MS = 20000;

const TIMEOUT_MARKER = Symbol('assistant_timeout');

/**
 * Valida o corpo do pedido. Devolve `{ error }` com o detalhe da primeira
 * falha encontrada, ou `{ value }` com o pedido já normalizado.
 */
function validateAskBody(body: any): { error?: string; value?: any } {
  if (!body || typeof body !== 'object') {
    return { error: 'Request body must be a JSON object' };
  }

  const { message, language, sessionId, history } = body;

  if (typeof message !== 'string') {
    return { error: 'Field "message" is required and must be a string' };
  }
  const trimmedMessage = message.trim();
  if (trimmedMessage.length < 1) {
    return { error: 'Field "message" must not be empty' };
  }
  if (trimmedMessage.length > MAX_MESSAGE_LENGTH) {
    return { error: `Field "message" must be at most ${MAX_MESSAGE_LENGTH} characters` };
  }

  if (typeof language !== 'string' || SUPPORTED_LANGUAGES.indexOf(language) === -1) {
    return { error: `Field "language" must be one of: ${SUPPORTED_LANGUAGES.join(', ')}` };
  }

  if (typeof sessionId !== 'string' || sessionId.trim().length < 1) {
    return { error: 'Field "sessionId" is required and must be a non-empty string' };
  }

  // `history` é opcional; entradas inválidas são descartadas em vez de rejeitarem
  // o pedido inteiro — o histórico é contexto auxiliar, não conteúdo obrigatório.
  let normalizedHistory: Array<{ role: string; text: string }> = [];
  if (Array.isArray(history)) {
    normalizedHistory = history
      .filter(
        (turn: any) =>
          turn &&
          (turn.role === 'visitor' || turn.role === 'assistant') &&
          typeof turn.text === 'string' &&
          turn.text.trim().length > 0
      )
      .map((turn: any) => ({ role: turn.role, text: turn.text }))
      .slice(-MAX_HISTORY_TURNS); // limitado no servidor para conter o tamanho do prompt
  }

  return {
    value: {
      message: trimmedMessage,
      language,
      sessionId: sessionId.trim(),
      history: normalizedHistory,
    },
  };
}

/** Corre uma promessa contra um timeout, sem deixar o temporizador pendurado. */
async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T | typeof TIMEOUT_MARKER> {
  let timer: NodeJS.Timeout;
  const timeout = new Promise<typeof TIMEOUT_MARKER>((resolve) => {
    timer = setTimeout(() => resolve(TIMEOUT_MARKER), ms);
  });

  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Regista o evento de utilização (FR-016).
 *
 * Nunca inclui o texto da pergunta nem o da resposta — apenas metadados de uso.
 * Uma falha a registar telemetria nunca pode estragar a resposta ao visitante,
 * por isso os erros são engolidos com um aviso.
 */
async function writeAnalytics(
  strapi: any,
  eventType: string,
  language: string,
  sessionId: string,
  success: boolean
) {
  try {
    await strapi.documents('api::analytics-event.analytics-event').create({
      // O content-type tem draft & publish ativo. Sem `status: 'published'` o
      // `documents().create()` cria só a versão draft, e a linha fica invisível
      // para a REST API e listada como não-publicada no admin — ao contrário de
      // todos os outros eventos, que a app envia pelo core create e ficam
      // publicados. Isto mantém as linhas do assistente consistentes com essas.
      status: 'published',
      data: {
        eventType,
        timestamp: new Date().toISOString(),
        sessionId,
        language,
        itemId: null,
        tourId: null,
        success,
        entidadeDocumentId: ACTIVE_ENTITY_DOCUMENT_ID,
        metadata: { source: 'assistant' },
      },
    });
  } catch (err) {
    strapi.log.warn(`[assistant] Falha ao registar analytics (${eventType}): ${err}`);
  }
}

export default ({ strapi }) => ({
  async ask(ctx) {
    const { error, value } = validateAskBody(ctx.request.body);

    if (error) {
      ctx.status = 400;
      ctx.body = { error: 'invalid_request', message: error };
      return;
    }

    const { message, language, sessionId, history } = value;

    // 1. Catálogo do museu no idioma ativo
    let catalog;
    try {
      catalog = await strapi.service('api::assistant.assistant-catalog').getCatalog(language);
    } catch (err) {
      strapi.log.error(`[assistant] Falha ao carregar o catálogo: ${err}`);
      await writeAnalytics(strapi, 'assistant_error', language, sessionId, false);
      ctx.status = 502;
      ctx.body = { error: 'assistant_unavailable' };
      return;
    }

    // 2. Chamada ao modelo, limitada pelo timeout do servidor
    let result;
    try {
      const outcome = await withTimeout(
        strapi.service('api::assistant.assistant-ai').ask({ catalog, message, language, history }),
        AI_TIMEOUT_MS
      );

      if (outcome === TIMEOUT_MARKER) {
        strapi.log.warn('[assistant] Timeout do servidor à espera do Gemini.');
        await writeAnalytics(strapi, 'assistant_error', language, sessionId, false);
        ctx.status = 504;
        ctx.body = { error: 'assistant_unavailable' };
        return;
      }

      result = outcome;
    } catch (err) {
      // Cobre tanto o erro de rede/API como a resposta estruturada que não
      // conseguiu ser interpretada — o serviço lança em ambos os casos.
      strapi.log.error(`[assistant] Falha na chamada ao Gemini: ${err}`);
      await writeAnalytics(strapi, 'assistant_error', language, sessionId, false);
      ctx.status = 502;
      ctx.body = { error: 'assistant_unavailable' };
      return;
    }

    // 3. Telemetria de utilização (sem qualquer texto de mensagem).
    // Uma recusa por estar fora de âmbito é registada como `assistant_decline`
    // (success: false) — continua a ser um 200 com resposta preenchida para o
    // visitante, mas não conta como pergunta respondida.
    const onTopic = result.onTopic !== false;
    const catalogSufficient = result.catalogSufficient !== false;

    // specs/003-assistant-web-fallback: só quando on-topic E o catálogo não
    // chega é que há um terceiro caminho (fallback de conhecimento) a
    // considerar; fora daí o comportamento é exatamente o da feature 001.
    if (!onTopic || catalogSufficient) {
      await writeAnalytics(
        strapi,
        onTopic ? 'assistant_question' : 'assistant_decline',
        language,
        sessionId,
        onTopic
      );

      ctx.status = 200;
      ctx.body = {
        answer: result.answer,
        autoTranslated: result.autoTranslated,
        onTopic,
        usedGeneralKnowledge: false,
      };
      return;
    }

    // 3b. Kill switch (FR-011): desligado => comportamento idêntico ao que
    // existia antes desta feature — a resposta "não tenho essa informação"
    // que a chamada primária já produz, sem fallback nem analytics novo.
    if (!KNOWLEDGE_FALLBACK_ENABLED) {
      await writeAnalytics(strapi, 'assistant_question', language, sessionId, true);

      ctx.status = 200;
      ctx.body = {
        answer: result.answer,
        autoTranslated: result.autoTranslated,
        onTopic: true,
        usedGeneralKnowledge: false,
      };
      return;
    }

    // 3c. Fallback de conhecimento (FR-003), limitado por AI_TIMEOUT_MS (a
    // chamada tem o mesmo perfil de latência da primária, sem pesquisa web).
    // Falha, timeout ou resultado sem confiança caem todos no mesmo desfecho:
    // a resposta "não tenho essa informação" da chamada primária (FR-009),
    // nunca um erro nem uma resposta inventada.
    let knowledgeResult;
    try {
      const outcome = await withTimeout(
        strapi
          .service('api::assistant.assistant-ai')
          .answerFromKnowledge({ catalog, message, language, searchTopic: result.searchTopic }),
        AI_TIMEOUT_MS
      );

      if (outcome === TIMEOUT_MARKER) {
        strapi.log.warn('[assistant] Timeout do servidor à espera do fallback de conhecimento.');
      } else {
        knowledgeResult = outcome;
      }
    } catch (err) {
      strapi.log.error(`[assistant] Falha no fallback de conhecimento: ${err}`);
    }

    const confident = !!(knowledgeResult && knowledgeResult.confident);

    // Regista `assistant_knowledge_fallback` em vez de `assistant_question` para
    // esta interação (research.md §9) — cobre os quatro sub-caminhos acima
    // (resposta com confiança, sem confiança, timeout, falha), nunca só o sucesso.
    await writeAnalytics(strapi, 'assistant_knowledge_fallback', language, sessionId, confident);

    ctx.status = 200;
    ctx.body = {
      answer: confident && knowledgeResult ? knowledgeResult.answer : result.answer,
      autoTranslated: false,
      onTopic: true,
      usedGeneralKnowledge: confident,
    };
  },
});
