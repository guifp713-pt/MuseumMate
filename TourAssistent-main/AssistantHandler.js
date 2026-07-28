// AssistantHandler.js — comunicação com o endpoint POST /api/assistant/ask
//
// Constitution Principle I: este módulo NÃO declara um baseUrl próprio.
// Reutiliza o do ApiHandler.js (Research §10) para não acrescentar uma terceira
// cópia independente ao problema já existente entre ApiHandler/AnalyticsHandler.
.import "ApiHandler.js" as Api

// Timeout do lado do cliente (Research §7, ai-museum-assistant; research.md §6,
// assistant-web-fallback). Tem de ser estritamente MAIOR que a soma do pior
// caso dos timeouts do servidor: o backend usa AI_TIMEOUT_MS (20s) tanto na
// chamada primária como no fallback de conhecimento (2ª chamada, só corre
// quando a pergunta é on-topic mas o catálogo é insuficiente) — até 40s no pior
// caso em que passa pelas duas, daí os 45s abaixo. Isto garante que o backend
// ganha sempre a corrida e consegue devolver um 502/504 estruturado em vez de o
// cliente desistir primeiro, quer a pergunta siga o caminho rápido (só a
// chamada primária) quer acione o fallback. Ao mexer nestes valores, rever ambos.
//
// O QML não tem setTimeout e o XMLHttpRequest do QML não expõe `timeout` de
// forma documentada, por isso quem conta o tempo é um Timer do lado QML
// (ChatIAPanel.qml), que lê esta constante e chama `.abort()` no objeto
// devolvido por askAssistant(). A decisão de qual callback disparar continua
// aqui, junto do resto da lógica de erro.
var REQUEST_TIMEOUT_MS = 45000

/**
 * Envia uma pergunta ao assistente.
 *
 * @param message        texto da pergunta do visitante (já validado como não-vazio)
 * @param language       idioma ativo da app: pt | en | es | fr
 * @param sessionId      id de sessão gerado pela app (partilhado com o Analytics)
 * @param history        turnos anteriores da sessão: [{ role, text }], antigo → recente
 * @param onSuccess      function({ answer, autoTranslated, onTopic, usedGeneralKnowledge })
 * @param onNetworkError function() — sem ligação à Internet (FR-008)
 * @param onServiceError function() — servidor/IA indisponível ou resposta inválida
 */
function askAssistant(message, language, sessionId, history, onSuccess, onNetworkError, onServiceError) {
    var url = Api.baseUrl + "/api/assistant/ask"

    var payload = {
        "message": message,
        "language": language,
        "sessionId": sessionId,
        "history": history || []
    }

    // Garante que cada pedido termina em exatamente um callback.
    var settled = false
    function settle(callback, arg) {
        if (settled) return
        settled = true
        if (callback) callback(arg)
    }

    var xhr = new XMLHttpRequest()
    xhr.open("POST", url, true)
    xhr.setRequestHeader("Content-Type", "application/json")

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return

        // status 0 em DONE = pedido abortado (timeout nosso ou rede caiu):
        // o onerror/timer trata desse caso.
        if (xhr.status === 0) return

        if (xhr.status !== 200) {
            console.warn("[Assistant] Resposta não-200 do servidor:", xhr.status)
            settle(onServiceError)
            return
        }

        try {
            var data = JSON.parse(xhr.responseText)
            if (typeof data.answer !== "string" || data.answer.length === 0) {
                console.warn("[Assistant] Resposta 200 sem campo 'answer' utilizável.")
                settle(onServiceError)
                return
            }

            settle(onSuccess, {
                       "answer": data.answer,
                       "autoTranslated": data.autoTranslated === true,
                       // Ausente => trata-se como on-topic, para não marcar
                       // uma resposta válida como recusa.
                       "onTopic": data.onTopic !== false,
                       // Indicador de resposta por conhecimento geral da IA
                       // (specs/003-assistant-web-fallback, FR-007). Campo aditivo —
                       // ausente em respostas antigas equivale a false.
                       "usedGeneralKnowledge": data.usedGeneralKnowledge === true
                   })
        } catch (e) {
            console.warn("[Assistant] Falha a interpretar a resposta:", e)
            settle(onServiceError)
        }
    }

    // Sem rota para o host: dispara de imediato, independentemente do timeout,
    // e é isto que cumpre o SC-006 (mensagem de "sem Internet" em < 5s).
    xhr.onerror = function() {
        console.warn("[Assistant] Erro de rede — sem ligação à Internet.")
        settle(onNetworkError)
    }

    console.log("[Assistant] A enviar pergunta para:", url)
    xhr.send(JSON.stringify(payload))

    // Handle devolvido ao chamador: permite ao Timer do QML cancelar o pedido
    // quando REQUEST_TIMEOUT_MS expira. Um pedido já resolvido ignora o abort.
    return {
        "abort": function() {
            if (settled) return
            console.warn("[Assistant] Timeout ao fim de", REQUEST_TIMEOUT_MS, "ms.")
            xhr.abort()
            settle(onServiceError)
        },
        "isSettled": function() { return settled }
    }
}
