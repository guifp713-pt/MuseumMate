import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import Qt5Compat.GraphicalEffects
import QZXing

import "AnalyticsHandler.js" as Analytics
import "ApiHandler.js" as AH

Item {
    id: homePageItem
    width:360
    height: 620

    signal back()
    property string linguaEscolhidaHome: ""
    property int currentFloor: 0
    property var colorpin: ["#FF3B30","#34C759","#FF9500","#E11D48","#A3E635","#FF2D55","#FACC15","#BE123C","#84CC16","#FB923C","#F43F5E","#FFD60A","#DC2626","#D9F99D","#F97316","#FF375F","#FDE047","#B91C1C","#65A30D","#EA580C"]
    property var areasPin: ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
    property var itemsPin: [1,2,3,4,5]
    property string corSelecionadaArea: ""
    property string areaSelcionada: ""
    property int selectedPinIndex: -1
    property int selectedPinIndexItem: -1
    property int selectedPinIndexEntity: 0
    property int recInformacoes: 270
    property double valorTimerEntity: 0.3
    property double valorTimerArea: 0.3
    property double valorTimerItem: 0.3

    property int valorAtualIndex: -1
    property string colorSelect: "#304993"

    property var appDataHomePage: ({})
    property var filteredItems: []
    property var currentSelectedItem: ({})
    property var currentSelectedMap: ({})

    property int valueBottomBar: 0
    property bool recFloorTrueOrFalse: true
    property int n: 0

    property string blackColor: "#1a1a1a"
    property string lightgrayColor:"white"

    property string welcomeMensage: appDataHomePage.dictionary["homePage_Introduction"]

    property int qrPageVisible: 0
    property int chatIAPageVisible: 0
    property var number: ["", "", "", ""]
    property bool qrScannerVisible: false
    property int currentIndex: 0
    property int verifyAnchors: -1
    property int countAnchors: 0
    property int saveIdItem: -1
    property int saveIdItemScan: -1
    property bool isProcessingQr: false

    property int valorContadorEffect: 20
    property int valorFinalAnimation: chatButtonIA.width + valorContadorEffect
    property int valorInicialAnimation: recChatButtonEffect.width

    Timer {
        id: timerPositionMap
        interval: 16
        running: false
        repeat: false
        onTriggered: {
            var pinX = mapScale.origin.x
            var pinY = mapScale.origin.y

            var meioX = imageMap.paintedWidth / 2
            var meioY = imageMap.paintedHeight / 2

            var mapW = imageMap.paintedWidth
            var mapH = imageMap.paintedHeight

            var offsetSmall = 0
            var offsetMedium = 0.50
            var offsetLarge = 0.45
            // Limpeza de âncoras para evitar conflitos
            itemInfoArea.anchors.left = undefined
            itemInfoArea.anchors.right = undefined
            itemInfoArea.anchors.top = undefined
            itemInfoArea.anchors.bottom = undefined

            itemInfoItem.anchors.left = undefined
            itemInfoItem.anchors.right = undefined
            itemInfoItem.anchors.top = undefined
            itemInfoItem.anchors.bottom = undefined

            // MOBILE
            if (homePageItem.width < 500) {
                var offsetX = mapW * offsetSmall
                var offsetY = mapH * offsetSmall

                if (pinY < meioY) {
                    mapTranslate.x = offsetX
                    mapTranslate.y = offsetY
                    itemInfoArea.anchors.bottom = homePageItem.bottom
                    itemInfoItem.anchors.bottom = homePageItem.bottom
                    verifyAnchors = 0
                } else {
                    mapTranslate.x = offsetX
                    mapTranslate.y = -offsetY
                    itemInfoArea.anchors.top = homePageItem.top
                    itemInfoItem.anchors.top = homePageItem.top
                    verifyAnchors = 1
                }
                // No mobile, ancora à direita do item principal
                itemInfoArea.anchors.right = homePageItem.right
                itemInfoItem.anchors.right = homePageItem.right

                countAnchors = 0

                if(verifyAnchors === 0) {
                    if(countAnchors % 2 === 0) {
                        itemInfoArea.anchors.bottomMargin = 0
                        itemInfoItem.anchors.bottomMargin = 0
                    } else {
                        itemInfoArea.anchors.bottomMargin = -150
                        itemInfoItem.anchors.bottomMargin = -150
                    }

                } else {
                    if(countAnchors % 2 === 0) {
                        itemInfoArea.anchors.topMargin = 0
                        itemInfoItem.anchors.topMargin = 0
                    } else {
                        itemInfoArea.anchors.topMargin = -150
                        itemInfoItem.anchors.topMargin = -150
                    }
                }
            }

            // TABLET
            else if (homePageItem.width < 800) {
                var scaledW = mapW * mapScale.xScale
                var scaledH = mapH * mapScale.yScale
                var desiredX = (mapW / 2) - pinX
                var desiredY = (mapH / 2) - pinY
                var maxTranslateX = (scaledW - mapW) / 2
                var maxTranslateY = (scaledH - mapH) / 2

                function clamp(v, min, max) {
                    return Math.max(min, Math.min(max, v))
                }

                var offsetXTab = mapW * 0.25
                var offsetYTab = mapH * offsetMedium // Usando a variável de offset correta

                mapTranslate.x = clamp(desiredX - offsetXTab, -maxTranslateX, maxTranslateX)
                mapTranslate.y = clamp(desiredY, -maxTranslateY, maxTranslateY)

                if (pinY < meioY) {
                    itemInfoArea.anchors.bottom = homePageItem.bottom
                    itemInfoItem.anchors.bottom = homePageItem.bottom
                } else {
                    itemInfoArea.anchors.top = homePageItem.top
                    itemInfoItem.anchors.top = homePageItem.top
                }
                itemInfoArea.anchors.right = homePageItem.right
                itemInfoItem.anchors.right = homePageItem.right
            }

            // DESKTOP
            else {
                var scaledW2 = mapW * mapScale.xScale
                var scaledH2 = mapH * mapScale.yScale
                var desiredX2 = (mapW / 2) - pinX
                var desiredY2 = (mapH / 2) - pinY
                var maxTranslateX2 = (scaledW2 - mapW) / 2
                var maxTranslateY2 = (scaledH2 - mapH) / 2

                function clamp2(v, min, max) {
                    return Math.max(min, Math.min(max, v))
                }

                var offsetXDesk = mapW * 0.20
                var offsetYDesk = mapH * offsetLarge // Definindo o offsetY para o Desktop

                mapTranslate.x = clamp2(desiredX2 - offsetXDesk, -maxTranslateX2, maxTranslateX2)
                mapTranslate.y = clamp2(desiredY2, -maxTranslateY2, maxTranslateY2)

                if (pinY < meioY) {
                    // Se clicar na parte de cima, painel aparece em baixo
                    itemInfoArea.anchors.bottom = homePageItem.bottom
                    itemInfoItem.anchors.bottom = homePageItem.bottom
                } else {
                    // Se clicar na parte de baixo, painel aparece em cima
                    itemInfoArea.anchors.top = homePageItem.top
                    itemInfoItem.anchors.top = homePageItem.top
                }
                // Garante que ancora à direita do componente pai (homePageItem)
                itemInfoArea.anchors.right = homePageItem.right
                itemInfoItem.anchors.right = homePageItem.right

                // Adiciona uma margem para não ficar colado à borda no desktop
                itemInfoArea.anchors.rightMargin = 20
                itemInfoItem.anchors.rightMargin = 20
            }
        }
    }

    Connections {
        target: typeof NfcManager !== "undefined" ? NfcManager : null

        function onTagDetected(documentId) {
            //Só executa se a HomePage estiver realmente visível
            if (!homePageItem.visible) {
                console.log("NFC QML (HomePage): Tag ignorada porque a página do mapa não está visível.")
                return
            }

            var cleanTag = String(documentId).trim()

            Qt.callLater(function() {
                processScannedCode(cleanTag)
            })
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (typeof isHomePageVisible !== "undefined") {
                isHomePageVisible = true;
            }

            // Verifica se há um código para ler pendente
            if (typeof pendingNfcCode !== "undefined" && pendingNfcCode !== "") {
                console.log("NFC QML (HomePage): onVisibleChanged detetou pendingNfcCode:", pendingNfcCode)

                var tagToProcess = pendingNfcCode
                pendingNfcCode = ""

                // Atraso intencional para garantir que o Loader terminou de ligar os dados
                Qt.callLater(function() {
                    processScannedCode(tagToProcess)
                })
            }
        } else {
            if (typeof isHomePageVisible !== "undefined") {
                isHomePageVisible = false;
            }
        }
    }

    Component.onDestruction: {
        // O Loader (WelcomePage.qml) destrói a HomePage diretamente ao trocar
        // de sourceComponent, sem passar por onVisibleChanged(false) primeiro.
        if (typeof isHomePageVisible !== "undefined") {
            isHomePageVisible = false;
        }
    }

    function formatTime(msec) {
        if (isNaN(msec) || msec <= 0) return "00:00";

        var totalSeconds = Math.floor(msec / 1000);
        var minutes = Math.floor(totalSeconds / 60);
        var seconds = totalSeconds % 60;

        var minutesStr = (minutes < 10 ? "0" : "") + minutes;
        var secondsStr = (seconds < 10 ? "0" : "") + seconds;

        return minutesStr + ":" + secondsStr;
    }

    function navigateToItem(itemData) {

        // --- Fechar o scanner ---
        qrScannerVisible = false
        qrPageVisible = 0
        cameraTour.active = false
        successEffectTour.play()

        // --- Passo 1: Definir o piso correto ---
        currentFloor = itemData.mapIndex

        // --- Passo 2: Replicar o clique na Área ---
        // itemData.areaIndex é relativo ao piso (ver ApiHandler.js getItems);
        // appDataHomePage.areas é uma lista global com todos os pisos seguidos,
        // por isso é preciso converter para o índice global antes de o usar.
        var areaIdx = -1
        var relCount = 0
        for (var a = 0; a < appDataHomePage.areas.length; a++) {
            if (Number(appDataHomePage.areas[a].mapIndex) === Number(itemData.mapIndex)) {
                if (relCount === itemData.areaIndex) {
                    areaIdx = a
                    break
                }
                relCount++
            }
        }

        if (areaIdx === -1) return  // área não encontrada (não deve acontecer)

        var areaData = appDataHomePage.areas[areaIdx]

        selectedPinIndex = areaIdx
        selectedPinIndexItem = areaIdx
        corSelecionadaArea = colorpin[areaIdx]
        areaSelcionada = areasPin[areaIdx]

        // Atualiza filteredItems com o piso e área corretos
        updateFilteredItems()

        // Visibilidade da UI
        retanguloComentario.visible = false
        itemBack.visible = false
        rowFloor.visible = false
        recbackzoom.color = colorpin[areaIdx]
        recbackzoom.visible = true
        retanguloitems.visible = true
        recRow.visible = false
        qrButtonHomePage.visible = false
        itemInfoEntity.visible = false
        itemInfoEntity.anchors.rightMargin = -240
        itemInfoEntity.anchors.bottomMargin = -310

        // Zoom para a área (fator configurável por entidade ativa — AH.getAreaZoom())
        mapScale.origin.x = areaData.posX * imageMap.paintedWidth
        mapScale.origin.y = areaData.posY * imageMap.paintedHeight
        mapScale.xScale = AH.getAreaZoom()
        mapScale.yScale = AH.getAreaZoom()
        timerPositionMap.running = true

        // Áudio da área
        player.stop()
        playerArea.source = areaData.audioArea
        playerArea.play()

        var itemIdx = -1
        for (var k = 0; k < filteredItems.length; k++) {
            if (filteredItems[k].documentId === itemData.documentId ||
                    filteredItems[k].code === itemData.code) {
                itemIdx = k
                break
            }
        }

        if (itemIdx === -1) return  // item não encontrado na área (não deve acontecer)

        itemInfoArea.visible = false
        recInformacoesItem.visible = true
        selectedPinIndexItem = itemIdx
        itemInfoItem.visible = true
        valorAtualIndex = itemIdx
        currentSelectedItem = filteredItems[itemIdx]
        listViewItems.positionViewAtBeginning()
        playerArea.stop()
        playerItem.source = itemData.audioItem
        playerItem.play()
        saveIdItemScan = itemData.id
        sendItemValidoScan.running = true
        scrollAutomate.running = true
        animationRecInformationsItem.running = true
    }

    function checkManualCode() {
        var code = homePageItem.number.join("").trim()
        homePageItem.number = ["", "", "", ""]
        homePageItem.currentIndex = 0

        for (var j = 0; j < appDataHomePage.items.length; j++) {
            if (String(appDataHomePage.items[j].code) === code) {
                navigateToItem(appDataHomePage.items[j])
                return
            }
        }
        cameraTour.active = false
        scannerPageTour.visible = false
        txtDetectQrCodeTour.visible = false
        rowCode.visible = false
        colCode.visible = false
        gridNumbersCode.visible = false
        errorEffectTour.playError()
    }

    Timer {
        id: animationRecInformations
        interval: 300
        running: true
        repeat: false
        onTriggered: {
            itemInfoEntity.anchors.rightMargin = 10
        }
    }

    Timer {
        id: animationRecInformationsArea
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            itemInfoArea.anchors.rightMargin = 10
        }
    }

    Timer {
        id: animationRecInformationsItem
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            itemInfoItem.anchors.rightMargin = 10
        }
    }


    Timer {
        id: scrollAutomate
        interval: 16
        running: false
        repeat: true
        onTriggered: {
            // Rola a entidade se estiver visível e tiver conteúdo maior que a altura
            if (listViewEntity.visible && listViewEntity.contentHeight > listViewEntity.height) {
                listViewEntity.contentY += valorTimerEntity
            }

            // Rola as áreas
            if (listViewAreas.visible && listViewAreas.contentHeight > listViewAreas.height) {
                listViewAreas.contentY += valorTimerArea
            }

            // Rola os itens
            if (listViewItems.visible && listViewItems.contentHeight > listViewItems.height) {
                listViewItems.contentY += valorTimerItem
            }
        }
    }

    //Timer Send Item Valido
    Timer {
        id: sendItemValido
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            Analytics.sendEvent("item_view", linguaEscolhidaHome, saveIdItem, null, root.sessionId, true)
        }
    }

    Timer {
        id: sendItemValidoScan
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            console.log("Code colected: ", saveIdItemScan)
            Analytics.sendEvent("item_view", linguaEscolhidaHome, saveIdItemScan, null, root.sessionId, true)
            Analytics.sendEvent("scan_success", linguaEscolhidaHome, saveIdItemScan, null, root.sessionId, true)
        }
    }

    function resetZoom() {
        selectedPinIndex = -1
        selectedPinIndexItem = -1
        mapScale.xScale = 1
        mapScale.yScale = 1
        mapTranslate.x = 0
        mapTranslate.y = 0
        recbackzoom.visible = false
        retanguloComentario.visible = true
        retanguloitems.visible = false
        itemInfoArea.visible = false
        recInformacoesItem.visible = false
        recRow.visible = true
        itemBack.visible = true
        rowFloor.visible = true
        itemInfoEntity.visible = true
        itemInfoArea.anchors.rightMargin = -240
        itemInfoItem.anchors.rightMargin = -310
        itemInfoItem.visible = false
        qrButtonHomePage.visible = true
        valorAtualIndex = -1
        sendItemValido.running = false
    }

    function processScannedCode(cleanTag) {
        console.log("NFC QML: Processando Tag:", cleanTag)

        // Proteção: Dados em falta da API
        if (!appDataHomePage || !appDataHomePage.items) {
            console.log("NFC QML: Dados em falta. Abortado.")
            return
        }

        // Procura o item correspondente ao ID lido.
        // A tag NFC contém o documentId do Strapi (tal como o QR code lido pela
        // câmara, ver ScannerPage.qml onTagFound) — não o "code" curto usado
        // apenas na inserção manual pelo teclado numérico.
        var itemEncontrado = null
        for (var j = 0; j < appDataHomePage.items.length; j++) {
            if (appDataHomePage.items[j] && String(appDataHomePage.items[j].documentId) === cleanTag) {
                itemEncontrado = appDataHomePage.items[j]
                break
            }
        }

        if (itemEncontrado !== null) {
            console.log("NFC QML: Item encontrado com sucesso:", itemEncontrado.nameItem)
            homePageItem.navigateToItem(itemEncontrado)
        } else {
            console.log("NFC QML: Nenhum item corresponde ao ID:", cleanTag)
            if (typeof errorEffectTour !== "undefined" && errorEffectTour) {
                errorEffectTour.playError()
            }
        }
    }

    function updateFilteredItems() {
        var allItems = appDataHomePage.items;
        var filtered = [];

        var targetFloor = Number(currentFloor);
        var globalAreaIndex = Number(selectedPinIndex);

        // 1. Calcular o índice relativo da área dentro do mapa atual
        var targetAreaRelative = 0;
        for (var a = 0; a < globalAreaIndex; a++) {
            if (Number(appDataHomePage.areas[a].mapIndex) === targetFloor) {
                targetAreaRelative++;
            }
        }

        // 2. Filtrar os itens comparando com o índice relativo correto
        for (var i = 0; i < allItems.length; i++) {
            var itemMapIndex = Number(allItems[i].mapIndex);
            var itemAreaIndex = Number(allItems[i].areaIndex); // Índice relativo do item

            if (itemMapIndex === targetFloor && itemAreaIndex === targetAreaRelative) {
                filtered.push(allItems[i]);
            }
        }
        filteredItems = filtered;
    }

    Component.onCompleted: {
        player.source = appDataHomePage.entities[0].audio
        player.play()
        scrollAutomate.running = true
        console.log("DEBUG LIFECYCLE: HomePage instanciada com sucesso.")

        // NOVA VERIFICAÇÃO: Se a página acabou de nascer via Loader por causa de um NFC
        if (typeof pendingNfcCode !== "undefined" && pendingNfcCode !== "") {
            console.log("NFC QML (HomePage): Component.onCompleted detetou pendingNfcCode:", pendingNfcCode)

            var tagToProcess = pendingNfcCode
            pendingNfcCode = "" // Limpa imediatamente

            // Usa um pequeno timer ou duplo callLater para garantir que o modelo de dados (appDataHomePage) está totalmente injetado
            Qt.callLater(function() {
                Qt.callLater(function() {
                    processScannedCode(tagToProcess)
                })
            })
        }
    }

    Rectangle {
        id: recbackzoom
        width: 50
        height: 50
        radius: 50
        border.color: "#9CA3AF"
        color: "white"
        visible: false
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 20
        z: 10

        Text {
            text: "x"
            font.pixelSize: 18
            color: "white"
            font.family: "Sans-Serif"
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                resetZoom()
            }
        }
    }

    Item {
        id: itemBack
        width: 150
        height: 32
        visible: qrPageVisible === 0
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 20

        Canvas {
            id: canva
            implicitWidth: 25
            implicitHeight: 26
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#9CA3AF"
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                ctx.beginPath()
                ctx.moveTo(8, 13); ctx.lineTo(3, 8); ctx.lineTo(8, 3)
                ctx.moveTo(13, 8); ctx.lineTo(3, 8)
                ctx.stroke()
            }
        }

        Text {
            text: appDataHomePage.dictionary["toursButtonBack"]
            font.family: "Sans-Serif"
            font.pixelSize: 12
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
            color: "#9CA3AF"
            anchors.left: parent.left
            anchors.leftMargin: 20
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                back()
                columnPrincipal.visible = true
                imgEntity.visible = true
                alterarLingua.visible = true
            }
        }
    }

    Row {
        id: rowFloor
        anchors.top: itemBack.bottom
        anchors.topMargin: 0
        anchors.left: parent.left
        anchors.right: parent.right      // dá uma largura finita ao Row
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        visible: true
        spacing: 10

        Repeater {
            model: currentFloor >= 0 ? 1 : 0
            delegate: Row {
                id: floorInfoRow
                width: rowFloor.width    // herda a largura finita
                spacing: 10
                property var mapData: appDataHomePage.maps[currentFloor]

                Text {
                    id: txtfloorMap
                    text: mapData.floorMap
                    font.family: playfairSemiBold.name
                    font.pixelSize: 26
                    color: "#000000"
                }

                Rectangle {
                    id: dash
                    width: 10
                    height: 2
                    color: "#9CA3AF"
                    anchors.top: parent.top
                    anchors.topMargin: 20
                }

                Text {
                    id: txtNameMap
                    text: mapData.nameMap
                    font.family: "Sans-Serif"
                    font.pixelSize: 12
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    color: "#9CA3AF"
                    anchors.top: parent.top
                    anchors.topMargin: 15
                    width: floorInfoRow.width - txtfloorMap.width - dash.width - (floorInfoRow.spacing * 2)
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Rectangle {
        id: recRow
        width: 100 // Ligeiramente aumentado para dar mais respiro ao texto
        height: 36
        color: "black"
        border.width: 0.5
        border.color: "#333333"
        radius: 18 // Metade da altura garante o formato de pílula perfeito
        visible: qrPageVisible === 0
        anchors.top: rowFloor.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 20

        Row {
            spacing: 8
            anchors.centerIn: parent

            Text {
                id: txtFoor
                // Correção da lógica de fallback do texto
                text: (appDataHomePage.dictionary["homePageFloor"]) + " " + currentFloor
                font.pixelSize: 14
                font.bold: true
                color: "white"
            }

            Text {
                id: txtFloor2
                text: "›" // Um caractere de seta mais elegante
                font.pixelSize: 16
                font.bold: true
                color: recFloor.visible ? "#D4AF37" : "white"

                // Roda dinamicamente baseado na visibilidade da lista abaixo
                rotation: recFloor.visible ? 90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 150 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Simplificação da lógica de toggle de visibilidade
                recFloor.visible = !recFloor.visible
                recFloorTrueOrFalse = !recFloor.visible
                n = recFloor.visible ? 1 : 0
            }
        }
    }
//==============================================================================================================

    Timer {
        id: timerEffectChat
        running: true
        interval: 600
        repeat: true
        onTriggered: {
            if(valorInicialAnimation < valorFinalAnimation) {
                recChatButtonEffect.border.color = "#D4AF37"
                recChatButtonEffect.width = recChatButtonEffect.width + 10
                recChatButtonEffect.height = recChatButtonEffect.height + 10
                valorInicialAnimation = valorInicialAnimation + 10
                recChatButtonEffect.opacity = recChatButtonEffect.opacity - 0.2
            }  else {
                recChatButtonEffect.width = chatButtonIA.width
                recChatButtonEffect.height = chatButtonIA.height
                valorInicialAnimation = chatButtonIA.width
                recChatButtonEffect.border.color = "transparent"
                recChatButtonEffect.opacity = 0.6
                timerEffectChat.running = false
                timerResetEffect.running = true
            }
        }
    }

    Timer {
        id: timerResetEffect
        running: false
        interval: 1000
        onTriggered: {
            timerEffectChat.running = true
            timerResetEffect.running = false
        }
    }


    GlobaLButtonChatIA {
        id: chatButtonIA
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        visible: chatIAPageVisible === 0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                chatIAPageVisible = 1
                qrPageVisible = 1
                recChat.anchors.bottomMargin = 0
                recBackground.visible = true
            }
        }
    }

    Rectangle {
        id: recChatButtonEffect
        width: chatButtonIA.width
        height: chatButtonIA.height
        border.color: "#D4AF37"
        color: "transparent"
        z: 9999
        radius: 50
        border.width: 2
        opacity: 0.6
        anchors.centerIn: chatButtonIA
        visible: chatButtonIA.visible ? true : false

        Behavior on width {NumberAnimation { duration: 500 }}
        Behavior on height {NumberAnimation { duration: 500 }}
    }

//==============================================================================================================

    GlobalQrButton {
        id: qrButtonHomePage
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: recRow.verticalCenter
        visible: qrPageVisible === 0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                homePageItem.isProcessingQr = false
                qrPageVisible = 1
                qrScannerVisible = true
            }
        }
    }

    Rectangle {
        id: recFloor
        width: recRow.width
        height: appDataHomePage.maps ? appDataHomePage.maps.length * 40 : 0
        z: 10

        // --- O que pediste: Margem e Alinhamento melhorados ---
        anchors.top: recRow.bottom
        anchors.topMargin: 6      // Margem subtil e elegante entre os blocos
        anchors.left: recRow.left  // Alinha perfeitamente pela esquerda do botão de cima

        color: "#1E1E1E"           // Tom escuro premium em vez do "red"
        border.width: 1
        border.color: "#333333"
        radius: 8                  // Cantos ligeiramente arredondados
        visible: false
        clip: true                 // Garante que o fundo dos itens respeita o raio dos cantos

        Column {
            id: columnFloor
            width: parent.width

            Repeater {
                model: appDataHomePage.maps
                delegate: Rectangle {
                    id: floorRec
                    width: parent.width
                    height: 40
                    // Um fundo ligeiramente destacado se for o piso atual
                    color: currentFloor === index ? "#2A2A2A" : "transparent"

                    // Separador subtil entre linhas (esconde na última linha)
                    Rectangle {
                        width: parent.width - 12
                        height: 1
                        color: "#2D2D2D"
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: index < (appDataHomePage.maps.length - 1)
                    }

                    Text {
                        text: modelData.floorMap ? modelData.floorMap : ""
                        font.pixelSize: 15
                        font.bold: currentFloor === index
                        // Destaque em ouro (#D4AF37) para o selecionado, cinza claro para os restantes
                        color: currentFloor === index ? "#D4AF37" : "#CCCCCC"
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            currentFloor = index
                            recFloor.visible = false
                            n = 0
                            if (typeof resetZoom === "function") resetZoom()
                        }
                    }
                }
            }
        }
    }

    // MAPA
    Rectangle {
        id: recTotal
        anchors.top: recRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Item {
            id: mapContainer
            anchors.centerIn: parent
            width: parent.width * 0.9
            height: parent.height * 0.8
            transform: [
                Scale {
                    id: mapScale
                    origin.x: 0
                    origin.y: 0

                    Behavior on xScale {
                        NumberAnimation {
                            duration: 300;
                            easing.type: Easing.InOutQuad
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: 300;
                            easing.type: Easing.InOutQuad
                        }
                    }
                },
                Translate {
                    id: mapTranslate
                }
            ]

            Image {
                id: imageMap
                width: parent.width
                height: parent.height
                fillMode: Image.PreserveAspectFit
                cache: true
                asynchronous: true
                source: (appDataHomePage.maps && appDataHomePage.maps.length > currentFloor)
                        ? appDataHomePage.maps[currentFloor].imageMapUrl
                        : ""
                mipmap: true
                smooth: true
                antialiasing: true
            }

            Rectangle {
                id: retanguloComentario
                color: "transparent"
                visible: true
                width: imageMap.paintedWidth
                height: imageMap.paintedHeight
                anchors.centerIn: parent

                Repeater {
                    model: appDataHomePage.areas
                    delegate: Item {
                        visible: modelData.mapIndex === currentFloor &&  qrPageVisible === 0
                        width: 30
                        height: 40

                        x: (modelData.posX * parent.width) - (width / 2)
                        y: (modelData.posY * parent.height) - (height / 2)

                        Rectangle {
                            width: 30
                            height: 30
                            radius: width / 2
                            color: colorpin[index]
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top

                            Rectangle {
                                width: 10
                                height: 10
                                color: colorpin[index]
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: -5
                                rotation: 45
                                z: -1
                            }

                            Text {
                                text: areasPin[index]
                                font.pixelSize: 18
                                color: "white"
                                font.bold: true
                                anchors.centerIn: parent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedPinIndex = index
                                selectedPinIndexItem = -1 // Correção do nome aqui
                                corSelecionadaArea = colorpin[index]
                                areaSelcionada = areasPin[index]

                                console.log("Area index clicado:", index,
                                            "mapIndex da área:", modelData.mapIndex)
                                updateFilteredItems()
                                console.log("filteredItems count:", filteredItems.length)
                                updateFilteredItems()

                                // Visibilidade da interface, prevenção de erros e bugs
                                retanguloComentario.visible = false
                                itemBack.visible = false
                                rowFloor.visible = false
                                recbackzoom.color = colorpin[index]
                                recbackzoom.visible = true
                                retanguloitems.visible = true
                                itemInfoArea.visible = true
                                itemInfoEntity.visible = false
                                recRow.visible = false
                                qrButtonHomePage.visible = false
                                player.stop()
                                playerItem.stop()
                                playerArea.source = modelData.audioArea
                                playerArea.play()

                                animationRecInformationsArea.running = true
                                scrollAutomate.running = true
                                itemInfoEntity.anchors.rightMargin = -240
                                itemInfoEntity.anchors.bottomMargin = -310
                                valorTimerEntity = 0

                                // Lógica de Zoom
                                // Pegamos a posição do PIN em relação ao tamanho da imagem pintada
                                var pinX = modelData.posX * imageMap.paintedWidth
                                var pinY = modelData.posY * imageMap.paintedHeight

                                // Centralizamos o ponto de origem do zoom no PIN
                                mapScale.origin.x = pinX
                                mapScale.origin.y = pinY
                                // Aplicamos o zoom (fator configurável por entidade ativa)
                                mapScale.xScale = AH.getAreaZoom()
                                mapScale.yScale = AH.getAreaZoom()
                                timerPositionMap.running = true
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: retanguloitems
                color: "transparent"
                visible: false
                width: imageMap.paintedWidth
                height: imageMap.paintedHeight
                anchors.centerIn: parent

                Repeater {
                    model: filteredItems

                    delegate: Item {
                        visible: true
                        width: 20
                        height: 30
                        x: (modelData.posXItem * parent.width) - (width / 2)
                        y: (modelData.posYItem * parent.height) - (height / 2)

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            opacity: 0.5
                        }

                        Rectangle {
                            id: cimaPinItem
                            width: 20
                            height: 20
                            radius: width / 2
                            color: valorAtualIndex != index ? corSelecionadaArea : colorSelect
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top

                            Rectangle {
                                id: baixoPinItem
                                width: 10
                                height: 10
                                color: valorAtualIndex != index ? corSelecionadaArea : colorSelect
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: -5
                                rotation: 45
                                z: -1
                            }

                            Text {
                                text: itemsPin[index]
                                font.pixelSize: 14
                                color: "white"
                                font.bold: true
                                anchors.centerIn: parent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                itemInfoArea.visible = false
                                recInformacoesItem.visible = true
                                selectedPinIndexItem = index
                                itemInfoItem.visible = true
                                animationRecInformationsItem.running = true
                                scrollAutomate.running = true
                                valorAtualIndex = index
                                listViewItems.positionViewAtBeginning()
                                currentSelectedItem = modelData
                                selectedPinIndexItem = index

                                sendItemValido.running = false
                                saveIdItem = modelData.id
                                sendItemValido.running = true

                                player.stop()
                                playerItem.source = modelData.audioItem
                                playerItem.play()
                                playerArea.stop()
                                countAnchors = 0
                                if(verifyAnchors === 0) {
                                    if(countAnchors % 2 === 0) {
                                        itemInfoArea.anchors.bottomMargin = 0
                                        itemInfoItem.anchors.bottomMargin = 0
                                    } else {
                                        itemInfoArea.anchors.bottomMargin = -150
                                        itemInfoItem.anchors.bottomMargin = -150
                                    }

                                } else {
                                    if(countAnchors % 2 === 0) {
                                        itemInfoArea.anchors.topMargin = 0
                                        itemInfoItem.anchors.topMargin = 0
                                    } else {
                                        itemInfoArea.anchors.topMargin = -150
                                        itemInfoItem.anchors.topMargin = -150
                                    }
                                }

                            }
                        }
                    }
                }
            }

            Item  {
                id: itemInfoEntity
                width: recInformacoes
                visible: true
                height: recInformacoesEntity.height
                anchors.right: parent.right
                anchors.rightMargin: -220
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                Behavior on anchors.rightMargin {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutQuad
                    }
                }


                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutQuad
                    }
                }

                Rectangle {
                    id: recCloseInfo
                    width: 60
                    height: 40
                    radius: 10
                    border.width: 1
                    color: blackColor
                    anchors.right: recInformacoesEntity.left
                    anchors.rightMargin: -20
                    anchors.top: recInformacoesEntity.top
                    anchors.topMargin: 50

                    Image {
                        id: i
                        width: 20
                        height: 20
                        source: "qrc:/images/images/nextIcon.png"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: recCloseInfo.width / 2 - 5
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if(itemInfoEntity.anchors.rightMargin > 0) {
                                itemInfoEntity.anchors.rightMargin = -240
                                itemInfoEntity.anchors.bottomMargin = -360
                                scrollAutomate.stop()
                                i.rotation = 180
                            } else {
                                itemInfoEntity.anchors.rightMargin = 10
                                itemInfoEntity.anchors.bottomMargin = 10
                                scrollAutomate.running = true
                                i.rotation = 90
                            }
                            animationRecInformations.running = false
                            valorTimerEntity = 0.3
                            listViewEntity.positionViewAtBeginning()  //Serve para o conteudo ser mostrado sempre encima
                        }
                    }
                }

                Rectangle {
                    id: recInformacoesEntity
                    width: recInformacoes
                    height: homePageItem.height / 2
                    visible:true
                    radius: 40
                    color: blackColor

                    ListView {
                        id: listViewEntity
                        anchors.fill: parent
                        anchors.margins: 20
                        model: (appDataHomePage.entities && appDataHomePage.entities.length > 0) ? 1 : 0
                        spacing: 15
                        clip: true
                        interactive: true
                        ScrollBar.vertical: null
                        onMovementStarted: {   //Se identificar scroll automaticamente para com o scroll Automatico
                            scrollAutomate.stop()
                        }
                        onContentYChanged: {
                            // Se o scroll atual somado à altura da janela atingir ou passar o tamanho total do conteúdo
                            if (contentY + height >= contentHeight) {
                                contentY = contentHeight - height; // Estabiliza no final
                                scrollAutomate.stop();             // Para a automação
                            }
                        }

                        delegate: Column {
                            width: listViewEntity.width
                            spacing: 15
                            property var entityData: appDataHomePage.entities[0]

                            Column {
                                width: listViewEntity.width
                                spacing: 0
                                Text {
                                    text: entityData.nameEntity
                                    font.pixelSize: 18
                                    font.family: playfairSemiBold.name
                                    color: "white"
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: appDataHomePage.dictionary["homePage_Introduction"]
                                    font.pixelSize: 14
                                    color: lightgrayColor
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }

                            Image {
                                source: entityData.imageEntityUrl
                                width: parent.width
                                fillMode: Image.PreserveAspectFit
                                cache: false
                            }
                            Rectangle {
                                width: parent.width
                                height: 60
                                border.width: 0.5
                                radius: 10
                                border.color: "#474444"
                                color: "#2a2a2a"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    spacing: 20

                                    Rectangle {
                                        id: playPauseButtonEntity
                                        width: 40
                                        height: 40
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 2
                                        border.color: "#C89B3C"
                                        visible: qrPageVisible === 0

                                        property bool isPlaying: false

                                        Image {
                                            id: imgPlayAudioEntity
                                            source: "qrc:/images/images/PlayButton.png"
                                            width: 17
                                            height: 17
                                            visible: player.playbackState !== MediaPlayer.PlayingState
                                            anchors.centerIn: parent
                                        }

                                        Image {
                                            id: pouseButton
                                            source: "qrc:/images/pouse.png"
                                            width: 20
                                            height: 20
                                            visible: player.playbackState === MediaPlayer.PlayingState
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                playPauseButtonEntity.isPlaying = !playPauseButtonEntity.isPlaying

                                                if(imgPlayAudioEntity.visible) {
                                                    imgPlayAudioEntity.visible = false
                                                    pouseButton.visible = true
                                                    player.source = entityData.audio
                                                    player.play()
                                                    playerArea.stop()
                                                    playerItem.stop()
                                                    scrollAutomate.running = true
                                                } else {
                                                    imgPlayAudioEntity.visible = true
                                                    pouseButton.visible = false
                                                    player.pause()
                                                    scrollAutomate.running = false
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.top: parent.top
                                        anchors.topMargin: 0
                                        width: parent.width - 60
                                        spacing:5

                                        Row {
                                            spacing: 8

                                            Image {
                                                source: "qrc:/images/images/audioIconGold.png"
                                                width: 13
                                                height: 13
                                            }
                                            Text {
                                                text: appDataHomePage.dictionary["tourPageAudioGuide"]
                                                font.pixelSize: 10
                                                color: "#9CA3AF"
                                                font.letterSpacing: 1.5
                                            }
                                        }
                                        Rectangle {
                                            id: progressBarBackground
                                            width: parent.width / 1.2
                                            height: 3
                                            color: "white"

                                            // 1. A BARRA DE PROGRESSO
                                            Rectangle {
                                                id: progressBarFill
                                                height: parent.height
                                                color: "#C89B3C"
                                                width: player.duration > 0 ? (player.position / player.duration) * parent.width : 0

                                                Behavior on width {
                                                    // Desativamos a animação se o usuário estiver interagindo para evitar "atraso" visual
                                                    enabled: !dragArea.pressed
                                                    NumberAnimation { duration: 200; easing.type: Easing.Linear }
                                                }
                                            }

                                            // 2. A BOLA (CONTROLLER)
                                            Rectangle {
                                                id: ballProgressAudio
                                                width: 14 // Um pouco maior para facilitar o toque
                                                height: 14
                                                radius: 7
                                                color: "#C89B3C"
                                                y: (parent.height / 2) - (height / 2) // Centraliza verticalmente

                                                // Posicionamento X: Segue o fim da barra de progresso
                                                // Subtraímos metade da largura (width/2) para a bola ficar centralizada na ponta
                                                x: progressBarFill.width - (width / 2)

                                                MouseArea {
                                                    id: dragArea
                                                    anchors.fill: parent
                                                    anchors.margins: -10 // Aumenta a área de toque sem aumentar a bola
                                                    drag.target: ballProgressAudio
                                                    drag.axis: Drag.XAxis
                                                    drag.minimumX: - (ballProgressAudio.width / 2)
                                                    drag.maximumX: progressBarBackground.width - (ballProgressAudio.width / 2)

                                                    // Enquanto arrasta, atualiza a posição do áudio
                                                    onPositionChanged: {
                                                        if (drag.active) {
                                                            updateAudioPosition()
                                                        }
                                                    }

                                                    // Se apenas clicar na bola
                                                    onReleased: updateAudioPosition()

                                                    function updateAudioPosition() {
                                                        if (player.duration > 0) {
                                                            // Calcula a porcentagem baseada no X da bola em relação ao fundo
                                                            let visualX = ballProgressAudio.x + (ballProgressAudio.width / 2)
                                                            let percentage = Math.max(0, Math.min(visualX / progressBarBackground.width, 1))
                                                            player.setPosition(percentage * player.duration)
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                z: -1 // Fica atrás da bola para não roubar o clique dela
                                                onClicked: (mouse) => {
                                                               if (player.duration > 0) {
                                                                   let percentage = mouse.x / width
                                                                   player.setPosition(percentage * player.duration)
                                                               }
                                                           }
                                            }
                                        }

                                        RowLayout {
                                            width: progressBarBackground.width

                                            Text {
                                                text: formatTime(player.position)
                                                font.pixelSize: 10
                                                color: lightgrayColor
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: formatTime(player.duration)
                                                font.pixelSize: 10
                                                color: lightgrayColor
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                id: welcomeEnMessagEntity
                                width: parent.width
                                text: entityData.welcome_message
                                wrapMode: Text.WordWrap
                                color: lightgrayColor
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: itemInfoArea
        width: recInformacoesAreas.width
        height: recInformacoesAreas.height
        visible: false
        anchors.right: parent.right
        anchors.rightMargin: -220

        Behavior on anchors.rightMargin {NumberAnimation {duration: 400;easing.type: Easing.InOutQuad}}
        Behavior on anchors.bottomMargin {NumberAnimation {duration: 400;easing.type: Easing.InOutQuad}}
        Behavior on anchors.topMargin {NumberAnimation {duration: 400; easing.type: Easing.InOutQuad}}

        Rectangle {
            id: recCloseInfoArea
            width: 60
            height: 40
            radius: 20
            border.width: 1
            color: blackColor
            anchors.right: recInformacoesAreas.left
            anchors.rightMargin: -20
            anchors.top: recInformacoesAreas.top
            anchors.topMargin: verifyAnchors != 0 ? recInformacoesAreas.height - 100 : 50

            Behavior on anchors.topMargin {NumberAnimation {duration: 400; easing.type: Easing.InOutQuad}}

            Image {
                id: i_Area
                width: 20
                height: 20
                source: "qrc:/images/images/nextIcon.png"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: recCloseInfo.width / 2 - 5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if(itemInfoArea.anchors.rightMargin >= 0) {
                        itemInfoArea.anchors.rightMargin = -220
                        //itemInfoArea.anchors.bottomMargin = -100
                        scrollAutomate.stop()
                        i_Area.rotation = 180
                    } else {
                        itemInfoArea.anchors.rightMargin = 10
                        scrollAutomate.running = true
                        i_Area.rotation = 0
                    }
                    listViewAreas.positionViewAtBeginning()

                    countAnchors++

                    if(verifyAnchors === 0) {
                        if(countAnchors % 2 === 0) {
                            itemInfoArea.anchors.bottomMargin = 0
                        } else {
                            itemInfoArea.anchors.bottomMargin = -150
                        }

                    } else {
                        if(countAnchors % 2 === 0) {
                            itemInfoArea.anchors.topMargin = 0
                        } else {
                            itemInfoArea.anchors.topMargin = -150
                        }
                    }
                }
            }
        }

        Rectangle {
            id: recInformacoesAreas
            width: recInformacoes
            height: homePageItem.height / 2
            radius: 40
            color: blackColor

            ListView {
                id: listViewAreas
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                clip: true
                interactive: true
                ScrollBar.vertical: null

                model: selectedPinIndex >= 0 ? 1 : 0

                onMovementStarted: scrollAutomate.stop()

                onContentYChanged: {
                    if (contentY + height >= contentHeight
                            && contentHeight > height) {
                        scrollAutomate.stop()
                    }
                }

                delegate: Column {
                    width: listViewAreas.width
                    spacing: 15

                    property var areaData:
                        appDataHomePage.areas[selectedPinIndex]

                    // ==========================================
                    // HEADER
                    // ==========================================

                    Column {
                        width: parent.width
                        spacing: 0

                        Text {
                            text: areaData.nameArea
                            font.pixelSize: 18
                            font.family: playfairSemiBold.name
                            color: "white"
                            font.bold: true
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            text: areaData.subtitleArea
                            font.pixelSize: 14
                            color: lightgrayColor
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    // ==========================================
                    // IMAGE
                    // ==========================================

                    Image {
                        source: areaData.imageAreaUrl
                        width: parent.width
                        fillMode: Image.PreserveAspectFit
                        cache: false
                    }

                    // ==========================================
                    // AUDIO PLAYER
                    // ==========================================

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 10
                        border.width: 0.5
                        border.color: "#474444"
                        color: "#2a2a2a"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20

                            // PLAY BUTTON

                            Rectangle {
                                id: playPauseButtonArea
                                width: 40
                                height: 40
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: "#C89B3C"

                                Image {
                                    id: imgPlayAudioArea
                                    source: "qrc:/images/images/PlayButton.png"
                                    width: 17
                                    height: 17
                                    visible: playerArea.playbackState !== MediaPlayer.PlayingState
                                    anchors.centerIn: parent
                                }

                                Image {
                                    id: pouseButtonArea
                                    source: "qrc:/images/pouse.png"
                                    width: 20
                                    height: 20
                                    visible: playerArea.playbackState === MediaPlayer.PlayingState

                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {

                                        if (playerArea.playbackState === MediaPlayer.PlayingState) {
                                            playerArea.pause()
                                            scrollAutomate.running = false
                                        } else {
                                            player.stop()
                                            playerItem.stop()
                                            playerArea.source = areaData.audioArea
                                            playerArea.play()
                                            scrollAutomate.running = true
                                        }
                                    }
                                }
                            }

                            // ==================================
                            // AUDIO INFO + PROGRESS
                            // ==================================

                            Column {
                                anchors.top: parent.top
                                anchors.topMargin: 0
                                spacing: 5

                                Row {
                                    spacing: 8

                                    Image {
                                        source:
                                            "qrc:/images/images/audioIconGold.png"
                                        width: 13
                                        height: 13
                                    }

                                    Text {
                                        text:
                                            appDataHomePage.dictionary["tourPageAudioGuide"]

                                        font.pixelSize: 10
                                        color: "#9CA3AF"
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Rectangle {
                                    id: progressBarBackgroundArea
                                    width: recInformacoesAreas.width / 2
                                    height: 3
                                    color: "white"

                                    Rectangle {
                                        id: progressBarFillArea
                                        height: parent.height
                                        color: "#C89B3C"
                                        width: playerArea.duration > 0 ? (playerArea.position / playerArea.duration) * parent.width : 0

                                        Behavior on width {
                                            enabled: !dragArea_Area.pressed

                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.Linear
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: ballProgressAudioArea
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: "#C89B3C"
                                        y:(parent.height / 2)  - (height / 2)
                                        x: progressBarFillArea.width - (width / 2)

                                        MouseArea {
                                            id: dragArea_Area

                                            anchors.fill: parent
                                            anchors.margins: -10
                                            drag.target:
                                                ballProgressAudioArea
                                            drag.axis: Drag.XAxis
                                            drag.minimumX:
                                                -(ballProgressAudioArea.width / 2)
                                            drag.maximumX:progressBarBackgroundArea.width - (ballProgressAudioArea.width / 2)

                                            onPositionChanged: {
                                                if (drag.active)
                                                    updateAudioPosition()
                                            }

                                            onReleased:
                                                updateAudioPosition()

                                            function updateAudioPosition() {

                                                if (playerArea.duration > 0) {

                                                    let visualX = ballProgressAudioArea.x + (ballProgressAudioArea.width / 2)
                                                    let percentage =
                                                        Math.max( 0, Math.min(visualX / progressBarBackgroundArea.width, 1))

                                                    playerArea.setPosition(
                                                                percentage
                                                                * playerArea.duration
                                                                )
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1

                                        onClicked: (mouse) => {

                                                       if (playerArea.duration > 0) {

                                                           let percentage =
                                                           mouse.x / width
                                                           playerArea.setPosition(percentage * playerArea.duration)
                                                       }
                                                   }
                                    }
                                }

                                RowLayout {
                                    width: progressBarBackgroundArea.width

                                    Text {
                                        text: formatTime(playerArea.position)
                                        font.pixelSize: 10
                                        color: lightgrayColor
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text:
                                            formatTime(playerArea.duration)
                                        font.pixelSize: 10
                                        color: lightgrayColor
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: descricaoArea
                        width: parent.width
                        text: areaData.descriptionArea
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                        color: lightgrayColor
                    }
                }
            }
        }
    }



    Item {
        id: itemInfoItem
        width: recInformacoesItem.width
        height: recInformacoesItem.height
        visible: false
        anchors.right: parent.right
        anchors.rightMargin: -220

        Behavior on anchors.rightMargin {NumberAnimation {duration: 400;easing.type: Easing.InOutQuad}}
        Behavior on anchors.bottomMargin {NumberAnimation {duration: 400;easing.type: Easing.InOutQuad}}
        Behavior on anchors.topMargin {NumberAnimation {duration: 400; easing.type: Easing.InOutQuad}}

        Rectangle {
            id: recCloseInfoItem
            width: 60
            height: 40
            radius: 20
            border.width: 1
            color: blackColor
            anchors.right: recInformacoesItem.left
            anchors.rightMargin: -20
            anchors.top: recInformacoesItem.top
            anchors.topMargin: verifyAnchors != 0 ? recInformacoesItem.height - 100 : 50

            Behavior on anchors.topMargin {NumberAnimation {duration: 400; easing.type: Easing.InOutQuad}}

            Image {
                id: i_Item
                width: 20
                height: 20
                source: "qrc:/images/images/nextIcon.png"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: recCloseInfo.width / 2 - 5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if(itemInfoItem.anchors.rightMargin >= 0) {
                        itemInfoItem.anchors.rightMargin = -220
                        scrollAutomate.stop()
                        i_Item.rotation = 180
                    } else {
                        itemInfoItem.anchors.rightMargin = 10
                        scrollAutomate.running = true
                        i_Item.rotation = 0
                    }

                    listViewItems.positionViewAtBeginning()

                    countAnchors++

                    if(verifyAnchors === 0) {
                        if(countAnchors % 2 === 0) {
                            itemInfoItem.anchors.bottomMargin = 0
                        } else {
                            itemInfoItem.anchors.bottomMargin = -150
                        }

                    } else {
                        if(countAnchors % 2 === 0) {
                            itemInfoItem.anchors.topMargin = 0
                        } else {
                            itemInfoItem.anchors.topMargin = -150
                        }
                    }
                }
            }
        }

        Rectangle {
            id: recInformacoesItem
            width: recInformacoes
            height: homePageItem.height / 2
            radius: 40
            color: blackColor

            ListView {
                id: listViewItems
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                clip: true
                interactive: true
                ScrollBar.vertical: null

                model: selectedPinIndexItem >= 0 ? 1 : 0

                onMovementStarted: scrollAutomate.stop()

                onContentYChanged: {
                    if (contentY + height >= contentHeight && contentHeight > height) {
                        scrollAutomate.stop()
                    }
                }

                delegate: Column {
                    width: listViewItems.width
                    spacing: 15

                    property var itemData: currentSelectedItem

                    Column {
                        width: parent.width

                        Text {
                            text: itemData.nameItem
                            font.pixelSize: 18
                            font.family: playfairSemiBold.name
                            color: "white"
                            font.bold: true
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    Image {
                        source: itemData.coverUrlItem
                        width: parent.width
                        fillMode: Image.PreserveAspectFit
                        cache: false
                    }

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 10
                        border.width: 0.5
                        border.color: "#474444"
                        color: "#2a2a2a"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20

                            Rectangle {
                                id: playPauseButtonItem
                                width: 40
                                height: 40
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: "#C89B3C"

                                Image {
                                    id: imgPlayAudioItem
                                    source:"qrc:/images/images/PlayButton.png"
                                    width: 17
                                    height: 17
                                    visible: playerItem.playbackState !== MediaPlayer.PlayingState
                                    anchors.centerIn: parent
                                }

                                Image {
                                    id: pouseButtonItem
                                    source: "qrc:/images/pouse.png"
                                    width: 20
                                    height: 20
                                    visible: playerItem.playbackState === MediaPlayer.PlayingState
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {
                                        if (playerItem.playbackState === MediaPlayer.PlayingState) {
                                            playerItem.pause()
                                            scrollAutomate.running = false
                                        } else {
                                            player.stop()
                                            playerArea.stop()
                                            playerItem.source = itemData.audioItem
                                            playerItem.play()
                                            scrollAutomate.running = true
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.top: parent.top
                                spacing: 5

                                Row {
                                    spacing: 8
                                    Image {
                                        source: "qrc:/images/images/audioIconGold.png"
                                        width: 13
                                        height: 13
                                    }

                                    Text {
                                        text: appDataHomePage.dictionary["tourPageAudioGuide"]
                                        font.pixelSize: 10
                                        color: "#9CA3AF"
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Rectangle {
                                    id: progressBarBackgroundItem
                                    width: recInformacoesAreas.width / 2
                                    height: 3
                                    color: "white"

                                    Rectangle {
                                        id: progressBarFillItem
                                        height: parent.height
                                        color: "#C89B3C"
                                        width: playerItem.duration > 0 ? (playerItem.position / playerItem.duration) * parent.width : 0

                                        Behavior on width {
                                            enabled: !dragArea_Item.pressed

                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.Linear
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: ballProgressAudioItem
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: "#C89B3C"
                                        y:(parent.height / 2)  - (height / 2)
                                        x: progressBarFillItem.width - (width / 2)

                                        MouseArea {
                                            id: dragArea_Item
                                            anchors.fill: parent
                                            anchors.margins: -10
                                            drag.target:
                                                ballProgressAudioItem
                                            drag.axis: Drag.XAxis
                                            drag.minimumX:
                                                -(ballProgressAudioItem.width / 2)
                                            drag.maximumX:progressBarBackgroundItem.width - (ballProgressAudioItem.width / 2)

                                            onPositionChanged: {
                                                if (drag.active)
                                                    updateAudioPosition()
                                            }

                                            onReleased:
                                                updateAudioPosition()

                                            function updateAudioPosition() {
                                                if (playerItem.duration > 0) {
                                                    let visualX = ballProgressAudioItem.x + (ballProgressAudioItem.width / 2)
                                                    let percentage = Math.max(0, Math.min(visualX / progressBarBackgroundItem.width, 1))
                                                    playerItem.setPosition(percentage * playerItem.duration)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1

                                        onClicked: (mouse) => {

                                                       if (playerItem.duration > 0) {
                                                           let percentage = mouse.x / width
                                                           playerItem.setPosition(percentage * playerItem.duration)
                                                       }
                                                   }
                                    }
                                }

                                RowLayout {
                                    width: progressBarBackgroundItem.width

                                    Text {
                                        text: formatTime(playerItem.position)
                                        font.pixelSize: 10
                                        color: lightgrayColor
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: formatTime(playerItem.duration)
                                        font.pixelSize: 10
                                        color: lightgrayColor
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: txtDescriptionItem
                        text: itemData.descriptionItem
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                        color: lightgrayColor
                        width: parent.width
                    }
                }
            }
        }
    }

    Rectangle {
        id: qrScannerOverlay
        anchors.fill: parent
        visible: qrScannerVisible
        z: 999
        color: "black"

        Flickable {
            id: flickQr
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: qrContent.implicitHeight + 60
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: qrContent
                width: flickQr.width
                height: flickQr.height
                spacing: 20
                x: 0
                y: 30

                Component.onCompleted: {
                    if (AndroidPermission.checkCameraPermission()) {
                        cameraTour.active = true
                    } else {
                        AndroidPermission.requestCameraPermission()
                        permissionTimerTour.start()
                    }
                }

                Timer {
                    id: permissionTimerTour
                    interval: 1000
                    repeat: false

                    onTriggered: {
                        if (AndroidPermission.checkCameraPermission()) {
                            cameraTour.active = true
                        }
                    }
                }

                Timer {
                    id: qrSuccessTimer
                    interval: 1500
                    repeat: false

                    onTriggered: {
                        successEffectTour.visible = false
                        qrScannerVisible = false
                        cameraTour.active = false
                        qrPageVisible = 0
                    }
                }

                Timer {
                    id: qrErrorTimer
                    interval: 2000
                    repeat: false

                    onTriggered: {
                        homePageItem.isProcessingQr = false
                        errorEffectTour.visible = false
                        scannerPageTour.visible = true
                        txtDetectQrCodeTour.visible = true
                        cameraTour.active = true
                        rowCode.visible = true
                        colCode.visible = true
                        gridNumbersCode.visible = true
                        zxingFilterTour.decoder.enabledDecoders =
                                QZXing.DecoderFormat_QR_CODE
                    }
                }

                Rectangle {
                    id: closePageTour
                    width: 40
                    height: 40
                    radius: 20
                    color: "#1A1A1A"
                    border.width: 1
                    border.color: "#2A2A2A"
                    anchors.right: parent.right
                    anchors.rightMargin: 24

                    Text {
                        text: "x"
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.family: interMedium.name
                        color: "#9CA3AF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: closePageTour.scale = 0.92
                        onReleased: closePageTour.scale = 1.0
                        onCanceled: closePageTour.scale = 1.0
                        onClicked: {
                            cameraTour.stop()
                            cameraTour.active = false
                            qrScannerVisible = false
                            qrPageVisible = 0
                        }
                    }
                }

                Column {
                    id: columnTxtQrCodeTour
                    width: parent.width - 40
                    spacing: 10
                    anchors.left: parent.left
                    anchors.leftMargin: 20

                    Text {
                        text: appDataHomePage.dictionary["scannerPageSmartAcces"]
                        font.family: interMedium.name
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        font.capitalization: Font.AllUppercase
                        color: "#D4AF37"
                    }

                    Column {
                        spacing: 5

                        Text {
                            text: appDataHomePage.dictionary["scannerPageScanQrCode"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "white"
                        }

                        Text {
                            text: appDataHomePage.dictionary["scannerPageDescription"]
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#6b7280"
                        }
                    }
                }

                Camera {
                    id: cameraTour
                    focusMode: Camera.FocusModeAutoNear
                }

                Rectangle {
                    id: scannerPageTour
                    width: parent.width - 85
                    height: 300
                    radius: 30
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    onVisibleChanged: {
                        if (visible) {
                            if (AndroidPermission.checkCameraPermission()) {
                                cameraTour.active = true
                            } else {
                                AndroidPermission.requestCameraPermission()
                            }
                        } else {
                            cameraTour.active = false
                            cameraTour.stop()
                        }
                    }

                    CaptureSession {
                        camera: cameraTour
                        videoOutput: videoOutputTour
                    }

                    Item {
                        id: videoContainerTour
                        anchors.fill: parent

                        VideoOutput {
                            id: videoOutputTour
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                            visible: false
                        }

                        Rectangle {
                            id: maskShapeTour
                            anchors.fill: parent
                            radius: 30
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: videoOutputTour
                            maskSource: maskShapeTour
                        }
                    }

                    QZXingFilter {
                        id: zxingFilterTour
                        videoSink: videoOutputTour.videoSink
                        orientation: videoOutputTour.orientation
                        decoder {
                            enabledDecoders: QZXing.DecoderFormat_QR_CODE
                            onTagFound: (tag) => {
                                            if (homePageItem.isProcessingQr) return;
                                            homePageItem.isProcessingQr = true;

                                            zxingFilterTour.decoder.enabledDecoders = QZXing.DecoderFormat_None

                                            var cleanTag = tag.trim()

                                            for (var j = 0; j < appDataHomePage.items.length; j++) {
                                                if (appDataHomePage.items[j].documentId === cleanTag) {
                                                    navigateToItem(appDataHomePage.items[j])
                                                    return
                                                }
                                            }

                                            // Não encontrado
                                            cameraTour.active = false
                                            scannerPageTour.visible = false
                                            txtDetectQrCodeTour.visible = false
                                            rowCode.visible = false
                                            colCode.visible = false
                                            gridNumbersCode.visible = false
                                            errorEffectTour.playError()
                                        }
                        }
                    }

                    Rectangle {
                        id: borderOverlayTour
                        anchors.fill: parent
                        radius: 30
                        color: "transparent"
                        border.width: 2
                        border.color: "#D4AF37"
                        clip: true

                        Rectangle {
                            id: scanningLineTour

                            width: parent.width
                            height: 2
                            gradient: Gradient {

                                orientation: Gradient.Horizontal

                                GradientStop {
                                    position: 0.0
                                    color: "transparent"
                                }

                                GradientStop {
                                    position: 0.5
                                    color: "#D4AF37"
                                }

                                GradientStop {
                                    position: 1.0
                                    color: "transparent"
                                }
                            }

                            SequentialAnimation on y {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    from: 0
                                    to: borderOverlayTour.height - scanningLineTour.height
                                    duration: 1800
                                    easing.type: Easing.InOutQuad
                                }

                                NumberAnimation {
                                    from: borderOverlayTour.height - scanningLineTour.height
                                    to: 0
                                    duration: 1800
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }

                Text {
                    id: txtDetectQrCodeTour
                    text: appDataHomePage.dictionary["scannerPageDetectQrCode"]
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: interRegular.name
                    font.pixelSize: 13
                    color: "#4B5563"
                    visible: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item {
                    id: successEffectTour
                    anchors.centerIn: parent
                    visible: false
                    opacity: 0
                    scale: 0.6

                    Rectangle {
                        id: imgSusseful
                        width: 120
                        height: 120
                        radius: 60
                        anchors.centerIn: parent
                        color: "black"
                        border.color: "#D4AF37"
                        border.width: 2

                        Image {
                            source: "qrc:/images/images/checkmark.png"
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        anchors.top: imgSusseful.bottom
                        anchors.topMargin: 30
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: appDataHomePage.dictionary["scannerPagerecognized"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "white"
                        }

                        Text {
                            text: appDataHomePage.dictionary["scannerPageLoadContent"]
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnimTour
                        running: false

                        NumberAnimation {
                            to: 1.2
                            duration: 200
                            easing.type: Easing.OutBack
                        }

                        NumberAnimation {
                            to: 1.0
                            duration: 200
                            easing.type: Easing.OutBack
                        }
                    }

                    SequentialAnimation {
                        id: fadeInTour
                        running: false

                        PropertyAnimation {
                            target: successEffectTour
                            property: "opacity"
                            to: 1
                            duration: 150
                        }
                    }

                    function play() {
                        visible = true
                        fadeInTour.start()
                        popAnimTour.start()
                        opacity = 1
                        scale = 1
                        qrSuccessTimer.restart()
                    }
                }

                Item {
                    id: errorEffectTour
                    anchors.centerIn: parent
                    visible: false
                    opacity: 0
                    scale: 0.6

                    Rectangle {
                        id: imgerror
                        width: 120
                        height: 120
                        radius: 60

                        anchors.centerIn: parent

                        color: "black"

                        border.color: "red"
                        border.width: 2

                        Image {
                            source: "qrc:/images/images/close.png"
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        anchors.top: imgerror.bottom
                        anchors.topMargin: 30
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: appDataHomePage.dictionary["scannerErrorQrCode"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "red"
                        }

                        Text {
                            text: appDataHomePage.dictionary["scannerComebackQrcode"]
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"

                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnimErrorTour
                        running: false

                        NumberAnimation {
                            to: 1.2
                            duration: 200
                            easing.type: Easing.OutBack
                        }

                        NumberAnimation {
                            to: 1.0
                            duration: 200
                            easing.type: Easing.OutBack
                        }
                    }

                    SequentialAnimation {
                        id: fadeInErrorTour
                        running: false

                        PropertyAnimation {
                            target: errorEffectTour
                            property: "opacity"
                            to: 1
                            duration: 150
                        }
                    }

                    function playError() {
                        visible = true
                        fadeInErrorTour.start()
                        popAnimErrorTour.start()
                        opacity = 1
                        scale = 1
                        qrErrorTimer.restart()
                    }
                }

                Row {
                    id: rowCode
                    width: parent.width - 40
                    spacing: 10
                    visible: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: line
                        width: (parent.width / 2) - 30
                        height: 1
                        color: "#4B5563"
                    }

                    Text {
                        text: appDataHomePage.dictionary["ScannerPageOr"]
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        font.letterSpacing: 1.32
                        font.capitalization: Font.AllUppercase
                        color: "#4b5563"
                        anchors.verticalCenter: line.verticalCenter
                    }

                    Rectangle {
                        width: (parent.width / 2) - 30
                        height: 1
                        color: "#4B5563"
                    }
                }

                Column {
                    id: colCode
                    spacing: 10
                    visible: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        id: txtEnterCode
                        text: appDataHomePage.dictionary["ScannerPageEnterCode"]
                        font.family: "sans-serif"
                        font.pixelSize: 12
                        font.letterSpacing: 1.54
                        font.capitalization: Font.AllUppercase
                        color: "#D4AF37"
                    }

                    Row {
                        id: rowRecCodes
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                id: recCodes
                                width: 55
                                height: 50
                                radius: 20
                                border.width: 2
                                border.color: homePageItem.currentIndex === index ? "#D4AF37" : "#2b2b2b"
                                color: "#1a1a1a"

                                Text {
                                    text: homePageItem.number[index]
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 25
                                }
                            }
                        }
                    }
                }

                Grid {
                    id: gridNumbersCode
                    rows: 4
                    columns: 3
                    spacing: 10
                    visible: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: 12
                        delegate: Rectangle {
                            width: 90
                            height: 54
                            radius: 12
                            color: mouseAreaKey.pressed ? "#2a2a2a" : "#1a1a1a"
                            visible: !isEmpty

                            property bool isEmpty: index === 9
                            property bool isZero: index === 10
                            property bool isDelete: index === 11

                            Behavior on color {
                                ColorAnimation { duration: 80 }
                            }


                            Text {
                                visible: !parent.isDelete
                                text: parent.isZero
                                      ? "0"
                                      : index + 1

                                anchors.centerIn: parent
                                color: "white"
                                font.pixelSize: 25
                            }

                            Image {
                                visible: parent.isDelete
                                source: "qrc:/images/images/delete.png"
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                            }

                            MouseArea {
                                id: mouseAreaKey
                                anchors.fill: parent
                                enabled: !parent.isEmpty
                                onClicked: {

                                    // BOTÃO DELETE
                                    if (parent.isDelete) {

                                        if (homePageItem.currentIndex > 0) {
                                            homePageItem.currentIndex--
                                            var temp = homePageItem.number
                                            temp[homePageItem.currentIndex] = ""
                                            homePageItem.number = temp
                                        }
                                        return
                                    }

                                    // NÚMERO
                                    if (homePageItem.currentIndex < 4) {
                                        var value = parent.isZero ? 0 : index + 1
                                        var temp = homePageItem.number
                                        temp[homePageItem.currentIndex] = value
                                        homePageItem.number = temp
                                        homePageItem.currentIndex++

                                        if (homePageItem.currentIndex === 4) {
                                            checkManualCode()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: recBackground
        anchors.fill: parent
        color: "black"
        opacity: 0.15
        visible: false

        // Faixa acima do painel: tocar fora do chat fecha-o
        Item {
            width: parent.width
            height: 56
            anchors.top: parent.top


            MouseArea {
                anchors.fill: parent
                onClicked: {
                    chatIAPageVisible = 0
                    qrPageVisible = 0
                    recChat.anchors.bottomMargin = -recChat.height
                    recBackground.visible = false
                }
            }
        }
    }

    ChatIAPanel {
        id: recChat
        width: parent.width
        height: parent.height - 56
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        activeLanguage: linguaEscolhidaHome
        sessionId: root.sessionId

        onCloseRequested: {
            chatIAPageVisible = 0
            qrPageVisible = 0
            recChat.anchors.bottomMargin = -recChat.height
            recBackground.visible = false
        }
    }


    MediaPlayer {
        id: player
        audioOutput: AudioOutput {}
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                // Quando acaba, garantimos que a barra volta ao início ou para
                player.stop()
                imgPlayAudioEntity.visible = true
                pouseButton.visible = false
            }
        }
    }

    MediaPlayer {
        id: playerArea
        audioOutput: AudioOutput {}
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                playerArea.stop()
            }
        }
    }

    MediaPlayer {
        id: playerItem
        audioOutput: AudioOutput {}
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                // Quando acaba, garantimos que a barra volta ao início ou para
                playerItem.stop()
            }
        }
    }

    FontLoader { id: playfairSemiBold; source: "qrc:/fonts/PlayfairDisplay-SemiBold.ttf" }
    FontLoader { id: interRegular; source: "qrc:/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interMedium; source: "qrc:/fonts/Inter_18pt-Medium.ttf" }
}
