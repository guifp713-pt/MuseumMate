// AnalyticsHandler.js
.import QtQuick.LocalStorage 2.0 as LS
// Constitution Principle I: ACTIVE_ENTITY_DOCUMENT_ID não é redeclarado aqui.
// Reutiliza o do ApiHandler.js (specs/004-analytics-multi-entity, research.md §2),
// seguindo o mesmo padrão já usado por AssistantHandler.js para o baseUrl.
.import "ApiHandler.js" as Api

//var baseUrl = "http://10.211.93.27:1337"    // ANDROID ESTAGIO
var baseUrl = "http://192.168.1.72:1337" // ANDROID CASA
/**
 * Abre a BD local e garante que as tabelas de cache e configurações existem
 */
function getDatabase() {
    var db = LS.LocalStorage.openDatabaseSync("AppDB", "1.0", "Cache", 1000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS analytics_cache (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT)")
        tx.executeSql("CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT)")

    })
    return db
}

/**
 * Cria ou recupera o Device ID ÚNICO e permanente deste telemóvel
 */
function getOrCreateDeviceId() {
    var deviceId = ""
    try {
        var db = getDatabase()
        db.transaction(function(tx) {
            var rs = tx.executeSql("SELECT value FROM app_settings WHERE key = 'device_id'")
            if (rs.rows.length > 0) {
                deviceId = rs.rows.item(0).value
            } else {
                // Gera um ID permanente único para este telemóvel
                deviceId = "DEV_" + Math.random().toString(36).substring(2, 12).toUpperCase() + Date.now().toString(36).toUpperCase()
                tx.executeSql("INSERT INTO app_settings (key, value) VALUES('device_id', ?)", [deviceId])
                console.log("[Analytics] Criado Device ID permanente para este dispositivo:", deviceId)
            }
        })
    } catch(e) {
        console.error("Erro ao processar o Device ID:", e)
        deviceId = "DEV_FALLBACK"
    }
    return deviceId
}

/**
 * Guarda o evento localmente quando a rede falha
 */
function saveToCache(payloadObj) {
    try {
        var db = getDatabase()
        db.transaction(function(tx) {
            var jsonStr = JSON.stringify(payloadObj)
            tx.executeSql("INSERT INTO analytics_cache (payload) VALUES(?)", [jsonStr])
        })
        console.log("[Cache Offline] Evento guardado localmente com sucesso!")
    } catch (e) {
        console.error("[Cache Offline] Erro ao guardar na BD local:", e)
    }
}

/**
 * Envia um evento de estatística para o Strapi (Aceita agora o 'success' como 6º parâmetro)
 */
function sendEvent(eventType, language, itemId, tourId, sessionId, success) {

    var timestamp = new Date().toISOString();
    var payload = {
        "data": {
            "eventType": eventType,
            "timestamp": timestamp,
            "sessionId": sessionId || "UNKNOWN_SESSION",
            "language": language || null,
            "itemId": itemId ? parseInt(itemId) : null,
            "tourId": tourId ? parseInt(tourId) : null,
            "success": success !== undefined ? success : true, // Preenche o teu campo Boolean
            "entidadeDocumentId": Api.ACTIVE_ENTITY_DOCUMENT_ID,
            "metadata": {
                "deviceId": getOrCreateDeviceId(),
                "source": "qml_application",
                "os": Qt.platform.os
            }
        }
    }

    var xhr = new XMLHttpRequest()
    var url = baseUrl + "/api/analytics-events"

    console.log("[Analytics] A enviar evento para o Strapi...", url)

    xhr.open("POST", url, true)
    xhr.setRequestHeader("Content-Type", "application/json")

    xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 201) {
                    console.log("[Analytics] Sucesso: " + eventType)
                } else {
                    console.error("[Analytics] Erro Strapi: " + xhr.responseText)
                    saveToCache(payload)
                }
            }
        }

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201) {
                console.log("[Analytics] Evento '" + eventType + "' enviado em tempo real!")
            } else {
                console.warn("[Analytics] Servidor inacessível (Status " + xhr.status + "). Guardando na cache...")
                saveToCache(payload)
            }
        }
    }

    xhr.onerror = function() {
        console.warn("[Analytics] Erro de rede. Guardando na cache...")
        saveToCache(payload)
    }

    xhr.send(JSON.stringify(payload))
}

/**
 * Saca tudo o que está na cache local e descarrega para o Strapi
 */
function syncCache() {
    try {
        var db = getDatabase()
        db.transaction(function(tx) {
            var rs = tx.executeSql("SELECT * FROM analytics_cache")
            if (rs.rows.length === 0) return

            console.log("[Sync] Encontrados " + rs.rows.length + " eventos em cache para sincronizar.")
            for (var i = 0; i < rs.rows.length; i++) {
                var row = rs.rows.item(i)
                enviarEventoAgendado(JSON.parse(row.payload), row.id)
            }
        })
    } catch (e) {
        console.error("[Sync] Erro ao ler a cache:", e)
    }
}

function enviarEventoAgendado(payloadObj, rowId) {
    var xhr = new XMLHttpRequest()
    var url = baseUrl + "/api/analytics-events"
    xhr.open("POST", url, true)
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            // Se foi aceite pelo Strapi (200/201) OU se o Strapi rejeitou permanentemente (400)
            if (xhr.status === 200 || xhr.status === 201 || xhr.status === 400) {

                if (xhr.status === 400) {
                    console.error("[Sync] Evento com ID " + rowId + " foi rejeitado pelo Strapi (Erro 400). A eliminar da cache para não bloquear...");
                } else {
                    console.log("[Sync] Evento em cache enviado e limpo com sucesso!")
                }

                var db = getDatabase()
                db.transaction(function(tx) {
                    tx.executeSql("DELETE FROM analytics_cache WHERE id = ?", [rowId])
                })
            } else {
                // Erros de rede/servidor em baixo (500, 503, status 0). Não faz nada e tenta no próximo sync.
                console.warn("[Sync] Servidor ainda indisponível para o ID " + rowId + " (Status: " + xhr.status + ")")
            }
        }
    }
    xhr.send(JSON.stringify(payloadObj))
}