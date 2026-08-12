.import QtQuick.LocalStorage 2.0 as LS

var cache = {}
var baseUrl = "http://192.168.1.72:1337" // ANDROID CASA
//var baseUrl = "http://10.211.93.27:1337" // ANDROID ESTAGIO
//var baseUrl = "http://192.168.5.175:1337/" // DESKTOP

//var ACTIVE_ENTITY_DOCUMENT_ID = "gqag59gr2pvu95qawb4dq1ol"  //Industria Textil Norte
var ACTIVE_ENTITY_DOCUMENT_ID = "ifajyzfd52v3tvq1mrf8j6eu"   //Museu de Portimao

// Fator de zoom aplicado em HomePage.qml quando se entra numa área do mapa.
// Espelha AREA_ZOOM_BY_ENTITY em backend/app/src/config/museum.ts (o campo
// customizado de criação de Items usa o mesmo conceito, lido via API). Chave =
// documentId da entidade; entidades não listadas usam DEFAULT_AREA_ZOOM.
// Trocar ACTIVE_ENTITY_DOCUMENT_ID acima já é suficiente para o zoom certo
// entrar em vigor automaticamente.
var DEFAULT_AREA_ZOOM = 2.0
var AREA_ZOOM_BY_ENTITY = {
    // Museu de Portimão — áreas fisicamente maiores do que a entidade fictícia;
    // 2.0 cortava itens fora do enquadramento. 1.3 é um valor de partida a
    // validar visualmente (suficiente para ver a área toda, com algum foco).
    "ifajyzfd52v3tvq1mrf8j6eu": 1.3
}

function getAreaZoom() {
    if (AREA_ZOOM_BY_ENTITY.hasOwnProperty(ACTIVE_ENTITY_DOCUMENT_ID)) {
        return AREA_ZOOM_BY_ENTITY[ACTIVE_ENTITY_DOCUMENT_ID]
    }
    return DEFAULT_AREA_ZOOM
}

// Injetado por main.qml (FileHelper.localFileExists) — não pode ser acedido
// diretamente daqui porque este módulo é passado explicitamente por parâmetro
// noutras funções (localPath), mantendo o mesmo padrão.
var fileExistsChecker = null

function setFileExistsChecker(fn) {
    fileExistsChecker = fn
}

function resolveUrl(path, localPath) {
    if (!path) return "";
    if (localPath) {
        var fileName = path.split("/").pop();
        var candidate = localPath + fileName;
        // Só usa o ficheiro local se ele já tiver sido de facto descarregado —
        // downloadFiles() é assíncrono e não avisa quando termina, por isso
        // localPath por si só não garante que o ficheiro existe em disco.
        if (fileExistsChecker && fileExistsChecker(candidate)) {
            return candidate;
        }
    }
    return baseUrl + path;
}

function openDb() {
    var db = LS.LocalStorage.openDatabaseSync("AppDB", "1.0", "Cache", 1000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS cache(lang TEXT, documentId TEXT, data TEXT)")
        // Migra instalações existentes (tabela criada antes desta feature, sem
        // a coluna documentId) — ignora o erro se a coluna já existir.
        // ATENÇÃO: em instalações migradas o ALTER acrescenta documentId no FIM
        // (lang, data, documentId), enquanto numa instalação nova a ordem é
        // (lang, documentId, data). Por isso todos os INSERT têm de nomear as
        // colunas explicitamente — nunca usar VALUES posicional nesta tabela.
        try {
            tx.executeSql("ALTER TABLE cache ADD COLUMN documentId TEXT")
        } catch (e) {
            // coluna já existe, nada a fazer
        }
        // Limpa linhas escritas pelo INSERT posicional antigo, que trocava as
        // colunas e deixava o JSON inteiro dentro de documentId. Nunca chegam a
        // corresponder a nenhuma leitura, só ocupavam espaço e acumulavam.
        // Um documentId real do Strapi tem ~25 caracteres.
        tx.executeSql("DELETE FROM cache WHERE length(documentId) > 64")
        tx.executeSql("CREATE TABLE IF NOT EXISTS tour_progress(tourDocumentId TEXT PRIMARY KEY, stepType TEXT, stepDocumentId TEXT, updatedAt TEXT)")
    })
    return db
}

/* ================================
   PROGRESSO DA VISITA GUIADA (local, por dispositivo)
================================ */

// Guarda o passo (item ou area) onde o visitante ficou, para poder retomar
// mais tarde (spec.md US4). Nunca guarda o passo "intro".
function saveTourProgress(tourDocumentId, stepType, stepDocumentId) {
    if (!tourDocumentId || !stepDocumentId) return
    var db = openDb()
    db.transaction(function(tx) {
        tx.executeSql(
                    "INSERT OR REPLACE INTO tour_progress(tourDocumentId, stepType, stepDocumentId, updatedAt) VALUES(?, ?, ?, ?)",
                    [tourDocumentId, stepType, stepDocumentId, new Date().toISOString()]
                    )
    })
}

// Lê o progresso guardado de uma tour. Devolve null se não existir nenhum.
function getTourProgress(tourDocumentId) {
    if (!tourDocumentId) return null
    var db = openDb()
    var resultado = null
    db.transaction(function(tx) {
        var rs = tx.executeSql("SELECT stepType, stepDocumentId FROM tour_progress WHERE tourDocumentId=?", [tourDocumentId])
        if (rs.rows.length > 0) {
            resultado = {
                stepType: rs.rows.item(0).stepType,
                stepDocumentId: rs.rows.item(0).stepDocumentId
            }
        }
    })
    return resultado
}

// Apaga o progresso guardado de uma tour (ao recomeçar ou ao concluir).
function clearTourProgress(tourDocumentId) {
    if (!tourDocumentId) return
    var db = openDb()
    db.transaction(function(tx) {
        tx.executeSql("DELETE FROM tour_progress WHERE tourDocumentId=?", [tourDocumentId])
    })
}

// Lê só a cache local (nunca acede à rede). Chama callback(dados) com o
// conteúdo guardado para a entidade ativa, ou callback(null) se não houver
// nenhuma linha válida — uma linha de um documentId antigo (incluindo linhas
// pré-migração, com documentId NULL) nunca corresponde à entidade atual.
function getCachedData(lang, callback) {
    var db = openDb()
    var resultado = null
    db.transaction(function(tx) {
        var rs = tx.executeSql("SELECT data FROM cache WHERE lang=? AND documentId=?", [lang, ACTIVE_ENTITY_DOCUMENT_ID])
        if (rs.rows.length > 0) {
            // Uma linha ilegível é tratada como ausência de cache (volta a
            // descarregar), nunca como exceção — um throw aqui dentro rebentaria
            // a transação e deixaria a app sem forma de recuperar.
            try {
                resultado = JSON.parse(rs.rows.item(0).data)
                console.log(" Cache encontrada para lingua:", lang)
            } catch (e) {
                console.error(" Cache ilegível, será descarregada de novo:", e)
                resultado = null
            }
        } else {
            console.log(" Sem cache para esta entidade/lingua")
        }
    })
    callback(resultado)
}

// Vai sempre à rede buscar o catálogo da entidade ativa; nunca lê nem escreve
// cache. callback(dados, errorReason): errorReason é null em sucesso,
// "not_found" se a entidade configurada não existir, "offline" se a rede falhar.
function fetchFromNetwork(lang, callback) {
    var url = baseUrl + "/api/entidades?filters[documentId][$eq]=" + ACTIVE_ENTITY_DOCUMENT_ID + "&locale=" + lang + "&populate[dictionaries]=true&populate[imageEntity]=true&populate[audio]=true&populate[tours][populate][imageTour]=true&populate[tours][populate][audioTour]=true&populate[tours][populate][items][populate][coverItem]=true&populate[tours][populate][items][populate][audioItem]=true&populate[tours][populate][items][populate][area]=true&populate[tours][populate][areas][populate][imageArea]=true&populate[tours][populate][areas][populate][audioArea]=true&populate[maps][populate][imageMap]=true&populate[maps][populate][areas][populate][imageArea]=true&populate[maps][populate][areas][populate][audioArea]=true&populate[maps][populate][areas][populate][items][populate][coverItem]=true&populate[maps][populate][areas][populate][items][populate][audioItem]=true&populate[maps][populate][areas][populate][items][populate][qrCodeImage]=true"
    console.log(" URL chamada:", url)

    var xhr = new XMLHttpRequest()
    xhr.open("GET", url, true)
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            console.log("Status HTTP:", xhr.status)
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText)
                    console.log("📦 response.data length:", response.data ? response.data.length : "NULL")
                    var dados = response.data
                    callback(dados, (!dados || dados.length === 0) ? "not_found" : null)
                } catch (e) {
                    console.error("Erro JSON:", e)
                    callback(null, "offline")
                }
            } else {
                console.error("HTTP falhou, status:", xhr.status)
                callback(null, "offline")
            }
        }
    }
    xhr.send()
}

// Grava/atualiza a cache local da entidade ativa para esta língua. Só deve ser
// chamado depois de o conteúdo (JSON + todos os media) estar de facto
// disponível localmente — caso contrário a cache passaria a existir sem os
// ficheiros que os dados descrevem.
function saveToCache(lang, dados) {
    var db = openDb()
    db.transaction(function(tx) {
        // Apaga só a linha desta entidade+língua — preserva a cache de outras
        // entidades (mesma língua) para permitir alternar entre museus (ex.:
        // testes A/B) sem perder o offline de nenhuma delas.
        tx.executeSql("DELETE FROM cache WHERE lang=? AND documentId=?", [lang, ACTIVE_ENTITY_DOCUMENT_ID])
        // Colunas nomeadas de propósito: a ordem física difere entre instalações
        // novas e migradas (ver openDb), por isso VALUES posicional gravaria os
        // dados nas colunas erradas e a cache nunca mais seria encontrada.
        tx.executeSql("INSERT INTO cache(lang, documentId, data) VALUES(?, ?, ?)", [lang, ACTIVE_ENTITY_DOCUMENT_ID, JSON.stringify(dados)])
    })
}

function getDictionary(dados) {

    var dictionary = {}

    if (!dados || dados.length === 0)
        return dictionary

    // PRIMEIRA ENTIDADE
    var rawData = Array.isArray(dados) ? dados[0] : dados
    var entidade = rawData.attributes || rawData
    var dictionaries = entidade.dictionaries || []

    for (var i = 0; i < dictionaries.length; i++) {

        var item = dictionaries[i]

        dictionary[item.key] = item.value
    }

    return dictionary
}

function getEntities(dados, localPath) {
    var entidades = []
    if (!dados || dados.length === 0) return entidades
    var rawData = Array.isArray(dados) ? dados[0] : dados;
    var entidade = (rawData && rawData.attributes) ? rawData.attributes : rawData;

    if (entidade) {
        var imgPath = (entidade.imageEntity?.data?.attributes?.url) || entidade.imageEntity?.url;
        var audioPath = (entidade.audio?.data?.attributes?.url) || entidade.audio?.url;

        entidades.push({
                           "nameEntity": entidade.nameEntity || "",
                           "descriptionEntity": entidade.descriptionEntity || "",
                           "welcome_message": entidade.welcome_message || "",
                           "audio": resolveUrl(audioPath, localPath),
                           "imageEntityUrl": resolveUrl(imgPath, localPath)
                       })
    }
    return entidades

}

function getMaps(dados, localPath) {
    var maps = []
    if (!dados || dados.length === 0) return maps
    var rawData = Array.isArray(dados) ? dados[0] : dados;
    var entidade = (rawData && rawData.attributes) ? rawData.attributes : rawData;

    if (entidade && entidade.maps) {
        for (var i = 0; i < entidade.maps.length; i++) {
            var mapa = entidade.maps[i]
            var imgPath = mapa.imageMap?.data?.attributes?.url || mapa.imageMap?.url;
            maps.push({
                          "floorMap": mapa.floorMap || "",
                          "nameMap": mapa.nameMap || "",
                          "imageMapUrl": resolveUrl(imgPath, localPath)
                      })
        }
    }
    return maps
}

function getAreas(dados, localPath) {
    var areas = []
    if (!dados || dados.length === 0) return areas
    var rawData = Array.isArray(dados) ? dados[0] : dados;
    var entidade = (rawData && rawData.attributes) ? rawData.attributes : rawData;

    if (entidade && entidade.maps) {
        for (var i = 0; i < entidade.maps.length; i++) {
            var mapa = entidade.maps[i]
            if (mapa.areas) {
                for (var j = 0; j < mapa.areas.length; j++) {
                    var area = mapa.areas[j]
                    var imgPath = area.imageArea?.data?.attributes?.url || area.imageArea?.url;
                    var audioPath = (area.audioArea?.data?.attributes?.url) || area.audioArea?.url;
                    areas.push({
                                   "id": area.id || 0,
                                   "documentId": area.documentId || "",
                                   "nameArea": area.nameArea || "",
                                   "subtitleArea": area.subtitleArea || "",
                                   "descriptionArea": area.descriptionArea || "",
                                   "posX": area.posX || 0,
                                   "posY": area.posY || 0,
                                   "audioArea": resolveUrl(audioPath, localPath),
                                   "imageAreaUrl": resolveUrl(imgPath, localPath),
                                   "mapIndex": i
                               })
                }
            }
        }
    }
    return areas
}

function getItems(dados, localPath) {
    var items = []
    if (!dados || dados.length === 0) return items
    var rawData = Array.isArray(dados) ? dados[0] : dados;
    var entidade = rawData.attributes ? rawData.attributes : rawData;

    if (entidade && entidade.maps) {
        for (var i = 0; i < entidade.maps.length; i++) {
            var mapa = entidade.maps[i]
            if (mapa.areas) {
                for (var j = 0; j < mapa.areas.length; j++) {
                    var area = mapa.areas[j]
                    if (area.items) {
                        for (var k = 0; k < area.items.length; k++) {
                            var item = area.items[k]
                            var imgPath = item.coverItem?.data?.attributes?.url || item.coverItem?.url;
                            var audioPath = (item.audioItem?.data?.attributes?.url) || item.audioItem?.url;
                            items.push({
                                           "id": item.id || "",
                                           "documentId": item.documentId || "",
                                           "nameItem": item.nameItem || "",
                                           "descriptionItem": item.descriptionItem || "",
                                           "posXItem": item.posXItem || 0,
                                           "posYItem": item.posYItem || 0,
                                           "coverUrlItem": resolveUrl(imgPath, localPath),
                                           "audioItem": resolveUrl(audioPath, localPath),
                                           qrCodeImage: item.qrCodeImage || "",
                                           "code": item.code || "",
                                           "areaIndex": j,
                                           "mapIndex": i
                                       })
                        }
                    }
                }
            }
        }
    }
    return items
}


/* ================================
   HELPERS
================================ */

function getRootEntity(dados) {
    if (!dados || !Array.isArray(dados) || dados.length === 0) return null;
    var rawData = dados[0];
    return rawData.attributes ? rawData.attributes : rawData;
}

function findTourByIdOrDocumentId(dados, tourRef) {
    var entidade = getRootEntity(dados);
    if (!entidade || !entidade.tours) return null;

    var tours = Array.isArray(entidade.tours)
            ? entidade.tours
            : entidade.tours.data || [];

    for (var i = 0; i < tours.length; i++) {
        var t = tours[i];
        var data = t.attributes || t;

        if (data.id === tourRef || data.documentId === tourRef) {
            return data;
        }
    }
    return null;
}

function findFullMapByIdOrDocumentId(dados, mapRef) {
    var entidade = getRootEntity(dados);
    if (!entidade || !entidade.maps) return null;

    for (var i = 0; i < entidade.maps.length; i++) {
        var mapa = entidade.maps[i];
        if (mapa.id === mapRef || mapa.documentId === mapRef) {
            return mapa;
        }
    }
    return null;
}

/* ================================
   TOUR ITEMS
================================ */

function getTourItems(dados, tourRef, localPath) {
    var items = [];

    var entidade = getRootEntity(dados);
    if (!entidade || !entidade.tours) return items;

    var tours = Array.isArray(entidade.tours)
            ? entidade.tours
            : entidade.tours.data || [];

    var tour = null;

    for (var i = 0; i < tours.length; i++) {
        var t = tours[i];
        var data = t.attributes ? t.attributes : t;

        if (data.id === tourRef || data.documentId === tourRef) {
            tour = data;
            break;
        }
    }

    if (!tour || !tour.items) return items;

    var rawItems = Array.isArray(tour.items)
            ? tour.items
            : tour.items.data || [];

    for (var i = 0; i < rawItems.length; i++) {
        var item = rawItems[i];
        var data = item.attributes ? item.attributes : item;

        var imgPath =
                data.coverItem?.data?.attributes?.url ||
                data.coverItem?.url ||
                "";

        var audioPath = (data.audioItem?.data?.attributes?.url) || data.audioItem?.url;

        var areaRaw = data.area?.data?.attributes ? data.area.data.attributes : (data.area?.data || data.area);

        items.push({
                       id: data.id || 0,
                       documentId: data.documentId || "",
                       nameItem: data.nameItem || "",
                       descriptionItem: data.descriptionItem || "",
                       posXItem: data.posXItem || 0,
                       posYItem: data.posYItem || 0,
                       code: data.code || "",
                       coverUrlItem: resolveUrl(imgPath, localPath),
                       audioItem: resolveUrl(audioPath, localPath),
                       areaDocumentId: areaRaw?.documentId || ""
                   });
    }

    return items;
}

/* ================================
   TOUR AREAS
================================ */

function getTourAreas(dados, tourRef, localPath) {
    var areas = [];

    var entidade = getRootEntity(dados);
    if (!entidade || !entidade.tours) return areas;

    var tours = Array.isArray(entidade.tours)
            ? entidade.tours
            : entidade.tours.data || [];

    var tour = null;

    for (var i = 0; i < tours.length; i++) {
        var t = tours[i];
        var data = t.attributes ? t.attributes : t;

        if (data.id === tourRef || data.documentId === tourRef) {
            tour = data;
            break;
        }
    }

    if (!tour || !tour.areas) return areas;

    var rawAreas = Array.isArray(tour.areas)
            ? tour.areas
            : tour.areas.data || [];

    for (var i = 0; i < rawAreas.length; i++) {
        var area = rawAreas[i];
        var data = area.attributes ? area.attributes : area;

        var imgPath = data.imageArea?.data?.attributes?.url || data.imageArea?.url || "";
        var audioPath = (data.audioArea?.data?.attributes?.url) || data.audioArea?.url;

        areas.push({
                       id: data.id || 0,
                       documentId: data.documentId || "",
                       nameArea: data.nameArea || "",
                       subtitleArea: data.subtitleArea || "",
                       descriptionArea: data.descriptionArea || "",
                       imageAreaUrl: resolveUrl(imgPath, localPath),
                       audioArea: resolveUrl(audioPath, localPath)
                   });
    }

    return areas;
}
/*==============================================TOURS===========================================================================================*/

function getTours(dados, localPath) {
    var tours = [];

    var entidade = getRootEntity(dados);
    if (!entidade || !entidade.tours) return tours;

    var rawTours =
            entidade.tours ||
            entidade.tours?.data;

    var list = Array.isArray(rawTours) ? rawTours : [rawTours];

    for (var i = 0; i < list.length; i++) {

        var item = list[i];
        var data = item.attributes || item;

        var rawItems =
                data.items ||
                data.items?.data;

        var totalParagens = rawItems
                ? (Array.isArray(rawItems) ? rawItems.length : 1)
                : 0;

        var imgPath =
                data.imageTour?.data?.attributes?.url ||
                data.imageTour?.url ||
                "";

        var audioPath =
                data.audioTour?.data?.attributes?.url ||
                data.audioTour?.url ||
                "";

        tours.push({
                       id: data.id || 0,
                       documentId: data.documentId || "",
                       nameTour: data.nameTour || "Sem nome",
                       timeTour: data.timeTour || "",
                       descriptionTour: data.descriptionTour || "",
                       imageTour: resolveUrl(imgPath, localPath),
                       audioTour: resolveUrl(audioPath, localPath),
                       isMainTour: data.isMainTour === true,
                       totalStops: totalParagens
                   });
    }

    return tours;
}

// Nova função para processar todos os itens de todos os tours de uma vez
function getAllTourItems(dados, localPath) {
    var result = {};
    var entidade = getRootEntity(dados);

    if (!entidade || !entidade.tours) return result;

    var tours = Array.isArray(entidade.tours)
            ? entidade.tours
            : (entidade.tours.data || []);

    for (var i = 0; i < tours.length; i++) {
        var t = tours[i];
        var data = t.attributes || t;
        var tourId = data.documentId || data.id;

        // Reutiliza a sua função getTourItems existente para cada tour individual
        result[tourId] = getTourItems(dados, tourId, localPath);
    }

    return result;
}

/* ================================
   SEQUÊNCIA DA VISITA GUIADA (intro + item + area)
================================ */

// Função pura: dado um tour (com nameTour/descriptionTour/imageTour/audioTour
// já resolvidos), os seus items (com areaDocumentId) e as areas associadas à
// tour, devolve a sequência ordenada de "passos" a apresentar na TourPage.
function buildTourSequence(tour, tourItems, tourAreas) {
    var steps = [];

    var areasById = {};
    for (var a = 0; a < (tourAreas || []).length; a++) {
        if (tourAreas[a] && tourAreas[a].documentId) {
            areasById[tourAreas[a].documentId] = tourAreas[a];
        }
    }

    if (tour && tour.audioTour) {
        steps.push({
                       type: "intro",
                       documentId: tour.documentId || "",
                       title: tour.nameTour || "",
                       description: tour.descriptionTour || "",
                       imageUrl: tour.imageTour || "",
                       audioUrl: tour.audioTour || "",
                       code: null,
                       stopNumber: null
                   });
    }

    var lastAreaDocumentId = null;
    var stopNumber = 0;
    var items = tourItems || [];

    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var itemAreaId = item.areaDocumentId || "";

        if (itemAreaId && itemAreaId !== lastAreaDocumentId && areasById[itemAreaId]) {
            var area = areasById[itemAreaId];
            stopNumber++;
            steps.push({
                           type: "area",
                           documentId: area.documentId,
                           title: area.nameArea || "",
                           description: [area.subtitleArea, area.descriptionArea].filter(function (s) { return !!s; }).join(" — "),
                           imageUrl: area.imageAreaUrl || "",
                           audioUrl: area.audioArea || "",
                           code: null,
                           stopNumber: stopNumber
                       });
        }

        if (itemAreaId) {
            lastAreaDocumentId = itemAreaId;
        }

        stopNumber++;
        steps.push({
                       type: "item",
                       documentId: item.documentId,
                       title: item.nameItem || "",
                       description: item.descriptionItem || "",
                       imageUrl: item.coverUrlItem || "",
                       audioUrl: item.audioItem || "",
                       code: item.code || "",
                       stopNumber: stopNumber
                   });
    }

    return steps;
}

// Nova função para pré-calcular a sequência guiada (intro/item/area) de todos
// os tours de uma vez, na mesma forma que getAllTourItems.
function getAllTourSteps(dados, localPath) {
    var result = {};
    var entidade = getRootEntity(dados);

    if (!entidade || !entidade.tours) return result;

    var tours = Array.isArray(entidade.tours)
            ? entidade.tours
            : (entidade.tours.data || []);

    var toursById = {};
    var toursList = getTours(dados, localPath);
    for (var k = 0; k < toursList.length; k++) {
        toursById[toursList[k].documentId] = toursList[k];
    }

    for (var i = 0; i < tours.length; i++) {
        var t = tours[i];
        var data = t.attributes || t;
        var tourId = data.documentId || data.id;

        var tourItems = getTourItems(dados, tourId, localPath);
        var tourAreas = getTourAreas(dados, tourId, localPath);
        var tourMeta = toursById[tourId] || null;

        result[tourId] = buildTourSequence(tourMeta, tourItems, tourAreas);
    }

    return result;
}

function extractMediaUrls(dados) {
    var urls = []
    if (!dados || dados.length === 0) return urls
    var rawData = Array.isArray(dados) ? dados[0] : dados
    var entidade = rawData.attributes ? rawData.attributes : rawData
    if (!entidade) return urls

    // 1. Imagem e Áudio da Entidade
    if (entidade.imageEntity) {
        var img = entidade.imageEntity.data?.attributes?.url || entidade.imageEntity.url
        if (img) urls.push(img)
    }
    if (entidade.audio) {
        var audio = entidade.audio.data?.attributes?.url || entidade.audio.url
        if (audio) urls.push(audio)
    }

    // 2. TOURS
    if (entidade.tours) {
        var tourArray = Array.isArray(entidade.tours) ? entidade.tours : [entidade.tours];
        for (var t = 0; t < tourArray.length; t++) {
            var tour = tourArray[t];

            // Imagem do Tour
            var tourImg =
                    tour.imageTour?.data?.attributes?.url ||
                    tour.imageTour?.url;

            if (tourImg) urls.push(tourImg);

            // Áudio de introdução do Tour
            var tourAudio =
                    tour.audioTour?.data?.attributes?.url ||
                    tour.audioTour?.url;

            if (tourAudio) urls.push(tourAudio);

            // --- Percorrer Itens do Tour ---
            if (tour.items && Array.isArray(tour.items)) {
                for (var ti = 0; ti < tour.items.length; ti++) {
                    var tourItem = tour.items[ti];
                    var tourItemImg = tourItem.coverItem?.data?.attributes?.url || tourItem.coverItem?.url;
                    if (tourItemImg) urls.push(tourItemImg);

                    var tourItemAudio =
                            tourItem.audioItem?.data?.attributes?.url ||
                            tourItem.audioItem?.url;

                    if (tourItemAudio) urls.push(tourItemAudio);
                }
            }
        }
    }

    // 3. MAPAS, ÁREAS e ITENS (via Mapas)
    if (entidade.maps) {
        for (var i = 0; i < entidade.maps.length; i++) {
            var mapa = entidade.maps[i]
            if (mapa.imageMap) {
                var mapImg = mapa.imageMap.data?.attributes?.url || mapa.imageMap.url
                if (mapImg) urls.push(mapImg)
            }
            if (mapa.areas) {
                for (var j = 0; j < mapa.areas.length; j++) {
                    var area = mapa.areas[j]
                    if (area.imageArea) {
                        var areaImg = area.imageArea.data?.attributes?.url || area.imageArea.url
                        if (areaImg) urls.push(areaImg)
                    }

                    if (area.audioArea) {
                        var areaAudio = area.audioArea.data?.attributes?.url || area.audioArea.url
                        if (areaAudio) urls.push(areaAudio)
                    }

                    if (area.items) {
                        for (var k = 0; k < area.items.length; k++) {
                            var item = area.items[k]

                            if (item.coverItem) {
                                var itemImg = item.coverItem.data?.attributes?.url || item.coverItem.url
                                if (itemImg) urls.push(itemImg)
                            }

                            if (item.audioItem) {
                                var itemAudio = item.audioItem.data?.attributes?.url || item.audioItem.url
                                if (itemAudio) urls.push(itemAudio)
                            }
                        }
                    }
                }
            }
        }
    }

    return urls
}
