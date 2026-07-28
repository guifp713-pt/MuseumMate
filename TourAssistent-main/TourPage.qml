import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtMultimedia
import QZXing

Item {
    id: root
    width: 400
    height: 600

    signal back()

        Component.onDestruction: {
            shutdownScanner()
        }

        // Deixa o onVisibleChanged apenas para segurança
        onVisibleChanged: {
            if (!visible) {
                shutdownScanner()
            }
        }

    // =========================================================================
    // --- LÓGICA DE DADOS (VERSÃO NOVA) ---
    property string linguaSelecionadaTourPage: ""
    property var appDataTourPage: ({})
    property var itemsGlobal: []
    property var tourInfo: null // Objeto do tour selecionado

    // Filtra os itens do tour selecionado automaticamente
    property var tourInfoItem: (tourInfo && appDataTourPage.tourItem)
                               ? appDataTourPage.tourItem[tourInfo.documentId || tourInfo.id] || []
                               : []

    property int contadorParagens: 1
    property int valorEstaticoStop: tourInfo ? tourInfo.totalStops : 0

    // Cálculos de progresso da versão antiga
    property int valorAtualStop: tourInfo ? tourInfo.totalStops : 0
    property int valorFinalStop: (valorAtualStop - (contadorParagens - 1)) || 1

    // Item atual baseado na paragem
    property var currentItem: (tourInfoItem.length > 0)
                              ? tourInfoItem[Math.min(contadorParagens - 1, tourInfoItem.length - 1)]
                              : null

    property int valorLista: 0
    property int valorExplorar: 0
    property bool qrScannerVisible: false
    property var number: ["", "", "", ""]
    property int currentIndex: 0
    property var items: []
    property var foundGlobalItem: null
    property string saveAudio: ""
    property int countIndex: 0
    property bool isAudioPlaying: false
    property int fakePosition: 0
    property int fakeDuration: 100000 // Valor dummy só para as barras não dividirem por zero
    property bool isAudioPaused: false
    property int audioPosition: 0
    property int audioDuration: 0

    // --- LIGAÇÃO BIDIRECIONAL COM O C++ E NOTIFICAÇÕES ---
    Connections {
        target: AudioBridge

        // Quando o C++ mudar a faixa, sincroniza a UI
        function onCurrentTrackChanged(index, url) {
            contadorParagens = index + 1
            isAudioPlaying = true
            saveAudio = url
        }

        function onAudioPositionChanged(position, duration) {
                if (!dragArea_Item.pressed) {
                    root.fakePosition = position      // Se a sua barra usa fakePosition, atualize aqui
                    root.fakeDuration = duration
                    root.audioPosition = position    // Atualize ambos ou remova os duplicados
                    root.audioDuration = duration
                }
            }
    }

    // --- LIGAÇÃO NFC (ISOLADA PARA A TOUR PAGE) ---
        Connections {
            target: typeof NfcManager !== "undefined" ? NfcManager : null

            // O parâmetro 'tagCode' é o valor ("3342") que o C++ acaba de enviar
            function onTagDetected(tagCode) {

                // PROTEÇÃO DE CONTEXTO: Só executa se a página das Visitas Guiadas estiver visível
                if (!root.visible) {
                    console.log("NFC QML (TourPage): Tag ignorada porque a TourPage não está visível.")
                    return;
                }

                // Lê diretamente o parâmetro enviado pelo C++ (e não o teclado root.number)
                var cleanTag = String(tagCode).trim()
                console.log("NFC QML (TourPage): Sinal detetado =", cleanTag)

                // SOLUÇÃO CRÍTICA: Qt.callLater para manter a sincronia da thread UI
                Qt.callLater(function() {
                    var found = false
                    var foundItemGlobal = false

                    // 1. Procura o item na tour atual usando o "code"
                    for (var i = 0; i < tourInfoItem.length; i++) {
                        // Forçamos para String caso a API envie o code como Inteiro
                        if (String(tourInfoItem[i].code) === cleanTag) {
                            found = true
                            contadorParagens = i + 1
                            valorLista = 1
                            valorExplorar = 1

                            playCurrentAudio()

                            // Garante que fecha a UI do scanner caso esteja aberta
                            cameraTour.active = false
                            scannerPageTour.visible = false
                            txtDetectQrCodeTour.visible = false
                            rowCode.visible = false
                            colCode.visible = false
                            gridNumbersCode.visible = false
                            getItem.visible = false

                            successEffectTour.play()
                            console.log("NFC QML (TourPage): Item encontrado na Tour!")
                            break
                        }
                    }

                    // 2. Se não encontrou na tour, verifica globalmente na app usando o "code"
                    if (!found) {
                        for (let j = 0; j < appDataTourPage.items.length; j++) {
                            if (String(appDataTourPage.items[j].code) === cleanTag) {
                                var globalItem = appDataTourPage.items[j]
                                root.foundGlobalItem = globalItem

                                AudioBridge.stopAudio()
                                AudioBridge.setPlaylist([globalItem.audioItem], 0)
                                AudioBridge.startAudio(globalItem.audioItem)

                                isAudioPlaying = true
                                root.isAudioPlaying = true
                                foundItemGlobal = true
                                getItem.visible = true

                                // Garante que fecha a UI do scanner caso esteja aberta
                                cameraTour.active = false
                                scannerPageTour.visible = false
                                txtDetectQrCodeTour.visible = false
                                rowCode.visible = false
                                colCode.visible = false
                                gridNumbersCode.visible = false

                                successEffectTour.play()
                                console.log("NFC QML (TourPage): Item encontrado Globalmente! (Fora da tour)")
                                break
                            }
                        }
                    }

                    // 3. Se o ID não existe em lado nenhum
                    if (!found && !foundItemGlobal) {
                        cameraTour.active = false
                        scannerPageTour.visible = false
                        txtDetectQrCodeTour.visible = false
                        rowCode.visible = false
                        colCode.visible = false
                        gridNumbersCode.visible = false

                        errorEffectTour.playError()
                        console.log("NFC QML (TourPage): Erro, nenhum item corresponde ao código:", cleanTag)
                    }
                });
            }
        }


    function checkManualCode() {
        var code = root.number.join("").trim()
        var found = false
        var foundItemGlobal = false

        // Primeiro: percorre TODOS os itens da tour
        for (var i = 0; i < tourInfoItem.length; i++) {
            if (tourInfoItem[i].code === code) {
                found = true
                contadorParagens = i + 1
                valorLista = 1
                valorExplorar = 1

                Qt.callLater(function() { playCurrentAudio() })

                cameraTour.active = false
                scannerPageTour.visible = false
                txtDetectQrCodeTour.visible = false
                rowCode.visible = false
                colCode.visible = false
                gridNumbersCode.visible = false
                getItem.visible = false

                root.number = ["", "", "", ""]
                root.currentIndex = 0
                successEffectTour.play()
                break
            }
        }

        // Só depois, SE não encontrou na tour, verifica globalmente
        if (!found) {
            for (let j = 0; j < appDataTourPage.items.length; j++) {
                if (appDataTourPage.items[j].code === code) {
                    var globalItem = appDataTourPage.items[j]
                    root.foundGlobalItem = globalItem

                    // ALTERAÇÃO NATIVA: Para o áudio antigo e arranca o áudio global via C++
                    AudioBridge.stopAudio()
                    AudioBridge.startAudio(globalItem.audioItem)
                    isAudioPlaying = true

                    foundItemGlobal = true
                    getItem.visible = true

                    cameraTour.active = false
                    scannerPageTour.visible = false
                    txtDetectQrCodeTour.visible = false
                    rowCode.visible = false
                    colCode.visible = false
                    gridNumbersCode.visible = false

                    root.number = ["", "", "", ""]
                    root.currentIndex = 0
                    successEffectTour.play()
                    break
                }
            }
        }

        // Se não encontrou em lado nenhum
        if (!found && !foundItemGlobal) {
            cameraTour.active = false
            scannerPageTour.visible = false
            txtDetectQrCodeTour.visible = false
            rowCode.visible = false
            colCode.visible = false
            gridNumbersCode.visible = false
            root.number = ["", "", "", ""]
            root.currentIndex = 0
            errorEffectTour.playError()
        }
    }

    function playCurrentAudio() {
        AudioBridge.stopAudio()
        if (currentItem && currentItem.audioItem) {

            var urls = [];
            for (var i = 0; i < tourInfoItem.length; i++) {
                urls.push(tourInfoItem[i].audioItem || "");
            }
            AudioBridge.setPlaylist(urls, contadorParagens - 1);

            // Iniciar áudio no Foreground Service do Android via C++
            AudioBridge.startAudio(currentItem.audioItem)
            isAudioPlaying = true
            saveAudio = currentItem.audioItem
            console.log("PLAY NATIVE AUDIO:", currentItem.audioItem)
        } else {
            isAudioPlaying = false
            console.log("SEM AUDIO")
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

    function shutdownScanner() {
        if (permissionTimerTour.running)
            permissionTimerTour.stop()

        try {
            zxingFilterTour.decoder.enabledDecoders = QZXing.DecoderFormat_None
        } catch (e) {}

        try {
            cameraTour.active = false
            cameraTour.stop()
        } catch (e) {}
    }


    Rectangle {
        anchors.fill: parent
        color: "white"

        // --- HEADER (LAYOUT ANTIGO + DICIONÁRIO NOVO) ---
        Text {
            id: txtnameTour
            text: tourInfo ? tourInfo.nameTour : ""
            font.family: "Sans-Serif"
            font.pixelSize: 10
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
            color: "#9CA3AF"
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 35
        }

        Text {
            id: txtParagemContador
            text: (appDataTourPage.dictionary["tourPageStop"] || "Paragem") + " " + contadorParagens
            font.pixelSize: 10
            font.family: "Sans-Serif"
            color: "#4B5563"
            font.letterSpacing: 1
            anchors.top: txtnameTour.bottom
            anchors.topMargin: 5
            anchors.left: parent.left
            anchors.leftMargin: 20
        }

        Rectangle {
            id: closePage
            width: 50
            height: 50
            radius: 50
            border.width: 0.5
            border.color: "#9CA3AF"
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 30

            Text {
                text: "x"
                font.pixelSize: 18
                color: "#4B5563"
                font.family: "Sans-Serif"
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    shutdownScanner()
                    AudioBridge.stopAudio()
                    isAudioPlaying = false

                    back()
                    recTours.visible = true
                }
            }
        }

        // --- BARRA DE PROGRESSO E PONTOS (LAYOUT ANTIGO) ---
        Rectangle {
            id: recProgressBar
            width: parent.width - 40
            height: 5
            radius: 20; color: "#9CA3AF"
            anchors.top: closePage.bottom
            anchors.topMargin: 20
            anchors.left: parent.left
            anchors.leftMargin: 20

            Rectangle {
                id: progressBar
                width: valorEstaticoStop > 0 ? (contadorParagens / valorEstaticoStop) * parent.width : 0
                height: parent.height
                radius: parent.radius; color: "#D4AF37"
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        Row {
            id: rowrecProgressBar
            anchors.top: recProgressBar.bottom
            anchors.topMargin: 10
            anchors.left: parent.left; anchors.leftMargin: 20
            spacing: 10

            Repeater {
                model: valorEstaticoStop
                delegate: Rectangle {
                    width: (contadorParagens - 1) === index ? 20 : 5
                    height: 5; radius: 50
                    color: (contadorParagens - 1) >= index ? "#D4AF37" : "#9CA3AF"

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
            }
        }

        Rectangle {
            id: recSelectMode
            width: parent.width - 40
            height: 35
            radius: 10
            anchors.top: rowrecProgressBar.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            color: "lightgray"

            Row {
                width: parent.width
                height: parent.height
                spacing: 0

                Rectangle {
                    width: parent.width / 2
                    height: parent.height
                    radius: 10
                    color: valorLista === 0 ? "black" : "lightgray"

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Image {
                            id: imgListWhite
                            source: valorLista === 0 ? "qrc:/images/images/list_white.png" : "qrc:/images/images/list_black.png"
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: txtList
                            text: appDataTourPage.dictionary["TourPage_List"]
                            font.pixelSize: 15
                            font.family: "Sans-Serif"
                            font.weight: Font.Light
                            color: valorLista === 0 ? "white" : "black"
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            valorExplorar = 0
                            valorLista = 0
                        }
                    }
                }

                Rectangle {
                    width: parent.width / 2
                    height: parent.height
                    radius: 10
                    color: valorExplorar === 0 ? "lightgray" : "black"

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Image {
                            id: imgExplorerBlack
                            source: valorExplorar === 0 ?  "qrc:/images/images/explorar_black.png" : "qrc:/images/images/explorar_white.png"
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: txtExplorer
                            text: appDataTourPage.dictionary["TourPage_Guide"]
                            font.pixelSize: 15
                            font.family: "Sans-Serif"
                            font.weight: Font.Light
                            color: valorExplorar === 0 ? "black" : "white"
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            valorExplorar = 1
                            valorLista = 1
                        }
                    }
                }
            }
        }

        Flickable {
            id: scrollAreaLista
            anchors.top: recSelectMode.bottom
            anchors.topMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: miniPlayer.visible ? (miniPlayer.height + 30) : 20
            width: parent.width
            contentHeight: contentColumnList.height
            clip: true
            visible: valorLista === 0
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: contentColumnList
                width: parent.width
                spacing: 15

                Repeater {
                    model: tourInfoItem
                    delegate: Rectangle {
                        id: recList
                        width: parent.width - 40
                        height: 100
                        radius: 10
                        border.width: 2
                        border.color: (contadorParagens - 1) === index ? "#D4AF37" : "#F3F4F6"
                        color: "#F3F4F6"
                        opacity: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Image {
                                source: modelData.coverUrlItem
                                width: 80
                                height: 80
                                fillMode: Image.PreserveAspectCrop
                            }

                            Column {
                                spacing: 5
                                width: parent.width - 100

                                Text {
                                    text: modelData.nameItem
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#111827"
                                }

                                Text {
                                    text: modelData.descriptionItem
                                    font.pixelSize: 12
                                    color: "#6B7280"
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                valorLista = 1
                                valorExplorar = 1
                                if (contadorParagens !== index + 1) {   // só age se for item diferente
                                    contadorParagens = index + 1
                                    playCurrentAudio()
                                }
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: scrollArea
            width: parent.width
            anchors.top: recSelectMode.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: miniPlayer.visible ? 65 : 20
            contentHeight: contentColumn.height
            clip: true
            visible: valorExplorar === 1
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: contentColumn
                width: parent.width
                spacing: 20
                bottomPadding: 20

                Item {
                    width: parent.width
                    height: 250
                    Image {
                        id: imgItems
                        source: currentItem ? currentItem.coverUrlItem : ""
                        width: parent.width - 40
                        height: 250
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        anchors.horizontalCenter: parent.horizontalCenter

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: imgItems.width
                                height: imgItems.height
                                radius: 15
                            }
                        }
                    }

                    Text {
                        text: currentItem ? currentItem.nameItem : ""
                        font.pixelSize: 20
                        font.family: "Times New Roman"
                        font.weight: Font.Light
                        font.letterSpacing: 1.2
                        font.capitalization: Font.AllUppercase
                        color: "white"
                        renderType: Text.NativeRendering
                        anchors.left: imgItems.left
                        anchors.leftMargin: 20
                        anchors.bottom: imgItems.bottom
                        anchors.bottomMargin: 20
                    }
                }

                // --- PLAYER DE ÁUDIO (MUDADO PARA CONTROLO NATIVO) ---
                Rectangle {
                    id: recProgressBarAudio
                    width: parent.width - 40
                    height: 60
                    radius: 10
                    border.width: 0.5
                    border.color: "#474444"
                    color: "#2a2a2a"
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Connections {
                    //     target: root
                    //     function onCurrentItemChanged() {
                    //         if (valorExplorar === 1) {
                    //             playCurrentAudio()
                    //         }
                    //     }
                    // }

                    Rectangle {
                        id: playPauseButtonItem
                        width: 30
                        height: 30
                        radius: 15
                        color: "transparent"
                        border.width: 2
                        border.color: "#C89B3C"
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            source: "qrc:/images/images/PlayButton.png"
                            width: 10
                            height: 10
                            anchors.centerIn: parent
                            visible: !root.isAudioPlaying
                        }

                        Image {
                            source: "qrc:/images/pouse.png"
                            width: 12
                            height: 12
                            anchors.centerIn: parent
                            visible: root.isAudioPlaying
                        }

                        MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.isAudioPlaying) {
                                        // Se está a tocar, faz pausa real (sem resetar)
                                        AudioBridge.pauseAudio()
                                        root.isAudioPlaying = false
                                        root.isAudioPaused = true
                                    } else {
                                        // Se não está a tocar, verifica se veio de uma pausa ou se é um áudio novo
                                        if (root.isAudioPaused) {
                                            AudioBridge.resumeAudio() // Retorna exatamente de onde parou
                                        } else {
                                            if (currentItem && currentItem.audioItem) {
                                                    AudioBridge.startAudio(currentItem.audioItem)
                                                }
                                        }
                                        root.isAudioPlaying = true
                                        root.isAudioPaused = false
                                    }
                                }
                            }
                    }

                    Column {
                        id: columnAudio
                        width: parent.width - playPauseButtonItem.width - 60
                        anchors.left: playPauseButtonItem.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Row {
                            spacing: 8

                            Image {
                                source: "qrc:/images/images/audioIconGold.png"
                                width: 13
                                height: 13
                            }

                            Text {
                                text: appDataTourPage.dictionary["tourPageAudioGuide"]
                                font.pixelSize: 10
                                color: "#9CA3AF"
                                font.letterSpacing: 1.5
                            }
                        }

                        Rectangle {
                            id: progressBarBackgroundItem
                            width: parent.width
                            height: 5
                            color: "#9CA3AF"
                            radius: 3

                            Rectangle {
                                id: progressBarFillItem
                                height: parent.height
                                radius: parent.radius
                                color: "#D4AF37"
                                // Usamos as propriedades falsas para manter a barra funcional visualmente
                                width: root.fakeDuration > 0
                                       ? (root.fakePosition / root.fakeDuration) * parent.width
                                       : 0

                                Behavior on width {enabled: !dragArea_Item.pressed ;NumberAnimation { duration: 200; easing.type: Easing.Linear }}}

                            Rectangle {
                                id: ballProgressAudioItem
                                width: 14
                                height: 14
                                radius: 7
                                color: "#D4AF37"
                                y: (parent.height / 2) - (height / 2)
                                x: progressBarFillItem.width - (width / 2)

                                MouseArea {
                                    id: dragArea_Item
                                    anchors.fill: parent
                                    anchors.margins: -10
                                    drag.target: ballProgressAudioItem
                                    drag.axis: Drag.XAxis
                                    drag.minimumX: -(ballProgressAudioItem.width / 2)
                                    drag.maximumX: progressBarBackgroundItem.width - (ballProgressAudioItem.width / 2)

                                    onPositionChanged: { if (drag.active) updateAudioPosition() }

                                    onReleased: {
                                        updateAudioPosition()
                                        ballProgressAudioItem.x = Qt.binding(function() {
                                            return progressBarFillItem.width - (ballProgressAudioItem.width / 2)
                                        })
                                    }

                                    function updateAudioPosition() {
                                        let visualX = ballProgressAudioItem.x + (ballProgressAudioItem.width / 2)
                                        let percentage = Math.max(0, Math.min(visualX / progressBarBackgroundItem.width, 1))
                                        let newPos = percentage * root.fakeDuration
                                        root.fakePosition = newPos

                                        // NOTIFICA O C++ (Adicione esta linha se tiver o método implementado no .h)
                                        AudioBridge.seek(newPos)
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: (mouse) => {
                                    let percentage = mouse.x / width
                                    let newPos = percentage * root.fakeDuration
                                    root.fakePosition = newPos
                                    AudioBridge.seek(newPos) // <--- Envia para o C++
                                }
                            }
                        }

                        RowLayout {
                            width: parent.width

                            Text {
                                text: formatTime(root.fakePosition)
                                font.pixelSize: 10
                                color: "#9CA3AF"
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: formatTime(root.fakeDuration)
                                font.pixelSize: 10
                                color: "#9CA3AF"
                            }
                        }
                    }
                }

                // --- DESCRIÇÃO ---
                Text {
                    text: currentItem ? currentItem.descriptionItem : ""
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 14
                    font.family: interRegular.name
                    color: "#4B5563"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }
            }
        }

        // --- RODAPÉ FIXO (LAYOUT ANTIGO + DICIONÁRIO NOVO) ---

        // Botão Anterior Ativo
        Rectangle {
            id: backStopTrue
            width: 120
            height: 50
            radius: 10
            color: "white"
            border.width: 1
            visible: valorExplorar === 1 && contadorParagens > 1? true : false
            anchors.right: nextStop.left
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20

            Text {
                text: " < " + appDataTourPage.dictionary["toursPrevious"]
                font.pixelSize: 15
                color: "#9CA3AF"
                anchors.centerIn: parent
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contadorParagens--
                    // ALTERAÇÃO NATIVA: Toca automaticamente a faixa anterior nativamente
                    playCurrentAudio()
                }
            }
        }

        // Botão Anterior Desativado
        Rectangle {
            width: 120
            height: 50
            radius: 10
            color: "white"
            border.width: 1
            visible: valorExplorar === 1 && contadorParagens === 1
            anchors.right: nextStop.left
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20

            Text {
                text: " < " + (appDataTourPage.dictionary["tourPageButtonBack"] || "Anterior")
                font.pixelSize: 15
                opacity: 0.5
                color: "#9CA3AF"
                anchors.centerIn: parent
            }
        }

        // Botão Próximo / Terminar
        Rectangle {
            id: nextStop
            width: 120
            height: 50
            radius: 10
            color: contadorParagens === valorEstaticoStop ? "#D4AF37" : "black"
            visible: valorExplorar === 1 ? true : false
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom;
            anchors.bottomMargin: 20

            Text {
                text: contadorParagens !== valorEstaticoStop
                      ? (appDataTourPage.dictionary["tourPageButtonNext"] || "Próximo") + " >"
                      : (appDataTourPage.dictionary["tourPageButtonEnd"] || "TERMINAR")
                font.pixelSize: 15
                font.bold: true
                color: "white"
                anchors.centerIn: parent
                font.capitalization: Font.AllUppercase
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (contadorParagens < valorEstaticoStop) {
                        contadorParagens++
                        // ALTERAÇÃO NATIVA: Avança para a paragem seguinte
                        playCurrentAudio()
                    } else {
                        // ALTERAÇÃO NATIVA: Para o áudio do Java ao terminar o tour
                        AudioBridge.stopAudio()
                        root.isAudioPlaying = false
                        back()
                        recTours.visible = true
                    }
                }
            }
        }

        // ─── MINI PLAYER — BARRA INFERIOR ───────────────────────────
        Rectangle {
            id: miniPlayer
            width: parent.width - 20
            height: 75
            radius: 10
            visible: valorExplorar === 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#111111"
            z: 10

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    valorExplorar = 1
                    valorLista = 1
                }
            }

            Rectangle {
                id: lineMiniPlayer
                width: parent.width - 20
                radius: 20
                height: 1
                color: "#2a2a2a"
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: miniProgressBg
                width: lineMiniPlayer.width
                height: 2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#2a2a2a"

                Rectangle {
                    id: miniProgressFill
                    width: (root.fakePosition / root.fakeDuration) * parent.width
                    height: parent.height
                    color: "#D4AF37"

                    Behavior on width {
                        enabled: !miniDragArea.pressed
                        NumberAnimation { duration: 200; easing.type: Easing.Linear }
                    }
                }

                Rectangle {
                    id: miniProgressBall
                    width: 10
                    height: 10
                    radius: 5
                    color: "#D4AF37"
                    y: (parent.height / 2) - (height / 2)
                    x: miniProgressFill.width - (width / 2)

                    MouseArea {
                        id: miniDragArea
                        anchors.fill: parent
                        anchors.margins: -10
                        drag.target: miniProgressBall
                        drag.axis: Drag.XAxis
                        drag.minimumX: -(miniProgressBall.width / 2)
                        drag.maximumX: miniProgressBg.width - (miniProgressBall.width / 2)

                        onPositionChanged: {
                            if (drag.active)
                                updateMiniAudioPosition()
                        }

                        onReleased: {
                            updateMiniAudioPosition()
                            miniProgressBall.x = Qt.binding(function() {
                                return miniProgressFill.width - (miniProgressBall.width / 2)
                            })
                        }

                        function updateAudioPosition() {
                            let visualX = ballProgressAudioItem.x + (ballProgressAudioItem.width / 2)
                            let percentage = Math.max(0, Math.min(visualX / progressBarBackgroundItem.width, 1))
                            let newPos = percentage * root.fakeDuration
                            root.fakePosition = newPos

                            // NOTIFICA O C++ (Adicione esta linha se tiver o método implementado no .h)
                            AudioBridge.seek(newPos)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: (mouse) => {
                        let percentage = mouse.x / width
                        let newPos = percentage * root.fakeDuration
                        root.fakePosition = newPos
                        AudioBridge.seek(newPos) // <--- Envia para o C++
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    width: 44
                    height: 44
                    radius: 10
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#2a2a2a"

                    Image {
                        anchors.fill: parent
                        source: currentItem ? currentItem.coverUrlItem : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#88000000"
                        visible: root.isAudioPlaying

                        Row {
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    id: bar
                                    width: 3
                                    radius: 2
                                    color: "#D4AF37"
                                    property real minH: 4
                                    property real maxH: 16
                                    height: minH
                                    anchors.bottom: parent ? parent.bottom : undefined

                                    SequentialAnimation on height {
                                        running: root.isAudioPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { to: bar.maxH; duration: 300 + index * 120; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: bar.minH; duration: 300 + index * 120; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - 44 - 10 - 28 - 8 - 40 - 8 - 28 - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    clip: true

                    Text {
                        text: currentItem ? currentItem.nameItem : ""
                        font.pixelSize: 12
                        font.family: playfairSemiBold.name
                        color: "#ffffff"
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        spacing: 4
                        Text {
                            text: formatTime(root.fakePosition)
                            font.pixelSize: 9
                            color: "#D4AF37"
                        }
                        Text {
                            text: "/ " + formatTime(root.fakeDuration)
                            font.pixelSize: 9
                            color: "#4b5563"
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: contadorParagens === 1 ? "transparent" : "#2a2a2a"
                    opacity: contadorParagens === 1 ? 0.3 : 1
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        source: "qrc:/images/images/nextIcon.png"
                        width: 12
                        height: 12
                        rotation: 180
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: contadorParagens > 1
                        onClicked: {
                            contadorParagens--
                            playCurrentAudio()
                        }
                    }
                }

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    border.width: 1
                    border.color: "#D4AF37"
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        source: root.isAudioPlaying
                                ? "qrc:/images/pouse.png"
                                : "qrc:/images/images/PlayButton.png"
                        width: 14
                        height: 14
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.isAudioPlaying) {
                                AudioBridge.pauseAudio()
                                root.isAudioPlaying = false
                                root.isAudioPaused = true
                            } else {
                                if (root.isAudioPaused) {
                                    AudioBridge.resumeAudio()
                                } else if (currentItem && currentItem.audioItem) {
                                    AudioBridge.startAudio(currentItem.audioItem)
                                }
                                root.isAudioPlaying = true
                                root.isAudioPaused = false
                            }
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: contadorParagens === valorEstaticoStop ? "transparent" : "#2a2a2a"
                    opacity: contadorParagens === valorEstaticoStop ? 0.3 : 1
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        source: "qrc:/images/images/nextIcon.png"
                        width: 12
                        height: 12
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: contadorParagens < valorEstaticoStop
                        onClicked: {
                            contadorParagens++
                            playCurrentAudio()
                        }
                    }
                }
            }
        }

        GlobalQrButton {
            id: qrButtonTourPage
            x: (root.width - closePage.width) - qrButtonTourPage.width - 40
            y: 30
            visible: true

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.number = ["", "", "", ""]
                    root.currentIndex = 0
                    qrScannerVisible = true
                    zxingFilterTour.decoder.enabledDecoders =
                            QZXing.DecoderFormat_QR_CODE
                    scannerPageTour.visible = true
                    cameraTour.active = true
                    txtDetectQrCodeTour.visible = true
                    rowCode.visible = true
                    colCode.visible = true
                    gridNumbersCode.visible = true
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

                Timer {
                    id: permissionTimerTour
                    interval: 1000
                    repeat: false
                    onTriggered: {
                        if (root.visible && scannerPageTour.visible && AndroidPermission.checkCameraPermission()) {
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
                    }
                }

                Timer {
                    id: qrErrorTimer
                    interval: 2000
                    repeat: false
                    onTriggered: {
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
                        text: appDataTourPage.dictionary["scannerPageSmartAcces"]
                        font.family: interMedium.name
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        font.capitalization: Font.AllUppercase
                        color: "#D4AF37"
                    }

                    Column {
                        spacing: 5

                        Text {
                            text: appDataTourPage.dictionary["scannerPageScanQrCode"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "white"
                        }

                        Text {
                            text: appDataTourPage.dictionary["scannerPageDescription"]
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
                            //cameraTour.stop()
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
                            visible: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: videoOutputTour.width
                                    height: videoOutputTour.height
                                    radius: 30
                                }
                            }
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
                                            zxingFilterTour.decoder.enabledDecoders =
                                            QZXing.DecoderFormat_None

                                            var cleanTag = tag.trim()
                                            var found = false
                                            var foundItemGlobal = false

                                            for (var i = 0; i < tourInfoItem.length; i++) {
                                                if (tourInfoItem[i].documentId === cleanTag) {
                                                    found = true
                                                    contadorParagens = i + 1
                                                    valorLista = 1
                                                    valorExplorar = 1

                                                    Qt.callLater(function() {
                                                        playCurrentAudio()
                                                    })

                                                    cameraTour.active = false
                                                    scannerPageTour.visible = false
                                                    txtDetectQrCodeTour.visible = false
                                                    rowCode.visible = false
                                                    colCode.visible = false
                                                    gridNumbersCode.visible = false
                                                    successEffectTour.play()
                                                    break
                                                }
                                            }

                                            if (!found) {
                                                for (let j = 0; j < appDataTourPage.items.length; j++) {
                                                    if (appDataTourPage.items[j].documentId === cleanTag) {
                                                        var globalItem = appDataTourPage.items[j]
                                                        root.foundGlobalItem = globalItem

                                                        AudioBridge.stopAudio()
                                                        AudioBridge.setPlaylist([globalItem.audioItem], 0) // Define playlist isolada de 1 item
                                                        AudioBridge.startAudio(globalItem.audioItem)
                                                        isAudioPlaying = true
                                                        root.isAudioPlaying = true
                                                        foundItemGlobal = true
                                                        getItem.visible = true
                                                        cameraTour.active = false
                                                        scannerPageTour.visible = false
                                                        txtDetectQrCodeTour.visible = false
                                                        rowCode.visible = false
                                                        colCode.visible = false
                                                        gridNumbersCode.visible = false
                                                        successEffectTour.play()
                                                        break
                                                    }
                                                }
                                            }

                                            if (!found && !foundItemGlobal) {
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
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: "#D4AF37" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }

                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0; to: borderOverlayTour.height - scanningLineTour.height; duration: 1800; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: borderOverlayTour.height - scanningLineTour.height; to: 0; duration: 1800; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                Text {
                    id: txtDetectQrCodeTour
                    text: appDataTourPage.dictionary["scannerPageDetectQrCode"]
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: interRegular.name
                    font.pixelSize: 13
                    color: "#4B5563"
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
                            text: appDataTourPage.dictionary["scannerPagerecognized"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "white"
                        }

                        Text {
                            text: appDataTourPage.dictionary["scannerPageLoadContent"]
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnimTour
                        running: false
                        NumberAnimation { to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        id: fadeInTour
                        running: false
                        PropertyAnimation { target: successEffectTour; property: "opacity"; to: 1; duration: 150 }
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
                            text: appDataTourPage.dictionary["scannerErrorQrCode"]
                            font.family: playfairSemiBold.name
                            font.pixelSize: 25
                            color: "red"
                        }

                        Text {
                            text: appDataTourPage.dictionary["scannerComebackQrcode"]
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnimErrorTour
                        running: false
                        NumberAnimation { to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        id: fadeInErrorTour
                        running: false
                        PropertyAnimation { target: errorEffectTour; property: "opacity"; to: 1; duration: 150 }
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
                        text: appDataTourPage.dictionary["ScannerPageOr"]
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
                        text: appDataTourPage.dictionary["ScannerPageEnterCode"]
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
                                border.color: root.currentIndex === index ? "#D4AF37" : "#2b2b2b"
                                color: "#1a1a1a"

                                Text {
                                    text: root.number[index]
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

                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                visible: !parent.isDelete
                                text: parent.isZero ? "0" : index + 1
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
                                    if (parent.isDelete) {
                                        if (root.currentIndex > 0) {
                                            root.currentIndex--
                                            var temp = root.number
                                            temp[root.currentIndex] = ""
                                            root.number = temp
                                        }
                                        return
                                    }

                                    if (root.currentIndex < 4) {
                                        var value = parent.isZero ? 0 : index + 1
                                        var temp = root.number
                                        temp[root.currentIndex] = value
                                        root.number = temp
                                        root.currentIndex++

                                        if (root.currentIndex === 4) {
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
        id: getItem
        anchors.fill: parent
        visible: false
        color: "#111111"

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: contentColumnItem.implicitHeight + 40

            Column {
                id: contentColumnItem
                width: root.width
                spacing: 20

                Item {
                    width: parent.width
                    height: 260

                    Image {
                        source: foundGlobalItem ? foundGlobalItem.coverUrlItem : ""
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.7; color: "#2e2e2e" }
                            GradientStop { position: 1.0; color: "#111111" }
                        }
                    }
                }

                Column {
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    Text {
                        text: foundGlobalItem ? foundGlobalItem.nameItem : ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 28
                        font.family: playfairSemiBold.name
                        color: "white"
                    }

                    // PLAYER AUDIO GLOBAL NATIVO
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: 10
                        border.width: 0.5
                        border.color: "#474444"
                        color: "#2a2a2a"

                        Row {
                            width: parent.width
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20

                            Rectangle {
                                id: playPauseButtonGlobal
                                width: 40
                                height: 40
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: "#C89B3C"

                                Image {
                                    id: imgPlayAudioGlobal
                                    source:"qrc:/images/images/PlayButton.png"
                                    width: 17
                                    height: 17
                                    visible: !root.isAudioPlaying
                                    anchors.centerIn: parent
                                }

                                Image {
                                    id: pouseButtonGlobal
                                    source: "qrc:/images/pouse.png"
                                    width: 20
                                    height: 20
                                    visible: root.isAudioPlaying
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (root.isAudioPlaying) {
                                            AudioBridge.stopAudio()
                                            root.isAudioPlaying = false
                                        } else {
                                            AudioBridge.startAudio(foundGlobalItem.audioItem)
                                            root.isAudioPlaying = true
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
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
                                        text: appDataTourPage.dictionary["tourPageAudioGuide"]
                                        font.pixelSize: 10
                                        color: "#9CA3AF"
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Rectangle {
                                    id: progressBarBackgroundGlobal
                                    width: parent.width / 2
                                    height: 3
                                    color: "white"

                                    Rectangle {
                                        id: progressBarFillGlobal
                                        height: parent.height
                                        color: "#C89B3C"
                                        width: (root.fakePosition / root.fakeDuration) * parent.width

                                        Behavior on width {
                                            enabled: !dragArea_Global.pressed
                                            NumberAnimation { duration: 200; easing.type: Easing.Linear }
                                        }
                                    }

                                    Rectangle {
                                        id: ballProgressAudioGlobal
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: "#C89B3C"
                                        y:(parent.height / 2)  - (height / 2)
                                        x: progressBarFillGlobal.width - (width / 2)

                                        MouseArea {
                                            id: dragArea_Global
                                            anchors.fill: parent
                                            anchors.margins: -10
                                            drag.target: ballProgressAudioGlobal
                                            drag.axis: Drag.XAxis
                                            drag.minimumX: -(ballProgressAudioGlobal.width / 2)
                                            drag.maximumX:progressBarBackgroundGlobal.width - (ballProgressAudioGlobal.width / 2)

                                            onPositionChanged: { if (drag.active) updateAudioPosition() }
                                            onReleased: updateAudioPosition()

                                            function updateAudioPosition() {
                                                let visualX = ballProgressAudioGlobal.x + (ballProgressAudioGlobal.width / 2)
                                                let percentage = Math.max(0, Math.min(visualX / progressBarBackgroundGlobal.width, 1))
                                                root.fakePosition = percentage * root.fakeDuration
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: (mouse) => {
                                                       let percentage = mouse.x / width
                                                       root.fakePosition = percentage * root.fakeDuration
                                                   }
                                    }
                                }

                                RowLayout {
                                    width: ballProgressAudioGlobal.width
                                    Text { text: formatTime(root.fakePosition); font.pixelSize: 10; color: "#9CA3AF" }
                                    Item { Layout.fillWidth: true }
                                    Text { text: formatTime(root.fakeDuration); font.pixelSize: 10; color: "#9CA3AF" }
                                }
                            }
                        }
                    }

                    Text {
                        text: foundGlobalItem ? foundGlobalItem.descriptionItem : ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.5
                        lineHeightMode: Text.ProportionalHeight
                        font.pixelSize: 14
                        font.family: interRegular.name
                        color: "#9CA3AF"
                    }
                }
            }
        }

        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: "#1A1A1A"
            border.width: 1
            border.color: "#2A2A2A"
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 20
            z: 20

            Text {
                text: "x"
                anchors.centerIn: parent
                color: "#9CA3AF"
                font.pixelSize: 16
                font.family: interMedium.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    getItem.visible = false
                    // ALTERAÇÃO NATIVA: Para o áudio global e volta para o áudio do tour nativo
                    AudioBridge.stopAudio()
                    if (saveAudio) {
                        AudioBridge.startAudio(saveAudio)
                        root.isAudioPlaying = true
                    } else {
                        root.isAudioPlaying = false
                    }
                }
            }
        }
    }

    FontLoader { id: playfairSemiBold; source: "qrc:/fonts/PlayfairDisplay-SemiBold.ttf" }
    FontLoader { id: playfairMedium; source: "qrc:/fonts/PlayfairDisplay-Medium.ttf" }
    FontLoader { id: interRegular; source: "qrc:/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interMedium; source: "qrc:/fonts/Inter_18pt-Medium.ttf" }
    FontLoader { id: interSemiBold; source: "qrc:/fonts/Inter_24pt-SemiBold.ttf" }
}