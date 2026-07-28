import QtQuick
import QtQuick.Controls
import QtMultimedia
import Qt5Compat.GraphicalEffects
import QZXing

Item {
    id: root
    width: 400
    height: 600

    signal back()

    property string linguaSelecionadaQrCode: ""
    property var currentItem: null
    property var appDataQrCode: ({})

    property var number: ["", "", "", ""]
    property int currentIndex: 0

    // ─── Função: pesquisa item pelo campo "code" ───────────────────────────────
    function checkManualCode() {
        var code = root.number.join("").trim()
        var items = appDataQrCode.items || []
        var foundItem = null

        for (var i = 0; i < items.length; i++) {
            if (String(items[i].code) === code) {
                foundItem = items[i]
                break
            }
        }

        // Reset do teclado
        root.number = ["", "", "", ""]
        root.currentIndex = 0

        if (foundItem) {
            currentItem = foundItem
            camera.active = false
            scannerContainer.visible = false
            txtDetectQrCode.visible = false
            codeSection.visible = false
            orDivider.visible = false
            successEffect.visible = true
            successEffect.play()
        } else {
            camera.active = false
            scannerContainer.visible = false
            txtDetectQrCode.visible = false
            codeSection.visible = false
            orDivider.visible = false
            errorEffect.visible = true
            errorEffect.playError()
        }
    }

    // ─── Timers ────────────────────────────────────────────────────────────────
    Timer {
        id: permissionTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (AndroidPermission.checkCameraPermission()) {
                camera.active = true
            } else {
                permissionDenied.visible = true
            }
        }
    }

    Timer {
        id: itemEncontrado
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            successEffect.visible = false
            getItem.visible = true
        }
    }

    Timer {
        id: itemEncontradoError
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            errorEffect.visible = false
            camera.active = true
            scannerContainer.visible = true
            codeSection.visible = true
            orDivider.visible = true
        }
    }

    // ─── Inicialização ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        if (AndroidPermission.checkCameraPermission()) {
            camera.active = true
        } else {
            AndroidPermission.requestCameraPermission()
            permissionTimer.start()
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  ECRÃ PRINCIPAL: SCANNER + TECLADO
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: scannerScreen
        anchors.fill: parent
        color: "black"
        visible: getItem.visible === false

        Flickable {
            id: flickQr
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: mainColumn.implicitHeight + 60
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: mainColumn
                width: flickQr.width
                height: flickQr.height
                spacing: 20
                x: 0
                y: 30

                // ── Botão fechar ──────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 50

                    Column {
                        id: columnTxtQrCode
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: appDataQrCode.dictionary["scannerPageSmartAcces"] || "SMART ACCESS"
                            font.family: interMedium.name
                            font.pixelSize: 12
                            font.letterSpacing: 2
                            font.capitalization: Font.AllUppercase
                            color: "#D4AF37"
                        }
                    }

                    Rectangle {
                        id: closeBtn
                        width: 40
                        height: 40
                        radius: 20
                        color: "#1A1A1A"
                        border.width: 1
                        border.color: "#2A2A2A"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "x"
                            font.pixelSize: 16
                            font.family: interMedium.name
                            color: "#9CA3AF"
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: closeBtn.scale = 0.92
                            onReleased: closeBtn.scale = 1.0
                            onCanceled: closeBtn.scale = 1.0
                            onClicked: {
                                camera.stop()
                                camera.active = false
                                back()
                            }
                        }
                    }
                }

                // ── Título e descrição ────────────────────────────────────────
                Column {
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5

                    Text {
                        text: appDataQrCode.dictionary["scannerPageScanQrCode"] || "Scan QR Code"
                        font.family: playfairSemiBold.name
                        font.pixelSize: 25
                        color: "white"
                    }

                    Text {
                        text: appDataQrCode.dictionary["scannerPageDescription"] || ""
                        font.family: interRegular.name
                        font.pixelSize: 12
                        color: "#6b7280"
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }

                // ── Câmera / Scanner ──────────────────────────────────────────
                Camera {
                    id: camera
                    active: false
                    focusMode: Camera.FocusModeAutoNear
                }

                Rectangle {
                    id: scannerContainer
                    width: parent.width - 85
                    height: 280
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 30
                    color: "transparent"

                    CaptureSession {
                        camera: camera
                        videoOutput: videoOutput
                    }

                    Item {
                        anchors.fill: parent

                        VideoOutput {
                            id: videoOutput
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                            visible: false
                        }

                        Rectangle {
                            id: maskShape
                            anchors.fill: parent
                            radius: 30
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: videoOutput
                            maskSource: maskShape
                        }
                    }

                    QZXingFilter {
                        id: zxingFilter
                        videoSink: videoOutput.videoSink
                        orientation: videoOutput.orientation
                        decoder {
                            enabledDecoders: QZXing.DecoderFormat_QR_CODE

                            onTagFound: (tag) => {
                                var cleanTag = tag.trim()
                                var items = appDataQrCode.items || []
                                var foundItem = null

                                for (var i = 0; i < items.length; i++) {
                                    if (items[i].documentId === cleanTag) {
                                        foundItem = items[i]
                                        break
                                    }
                                }

                                if (foundItem) {
                                    currentItem = foundItem
                                    camera.active = false
                                    scannerContainer.visible = false
                                    orDivider.visible = false
                                    codeSection.visible = false
                                    txtDetectQrCode.visible = false
                                    successEffect.visible = true
                                    successEffect.play()
                                } else {
                                    camera.active = false
                                    scannerContainer.visible = false
                                    orDivider.visible = false
                                    codeSection.visible = false
                                    txtDetectQrCode.visible = false
                                    errorEffect.visible = true
                                    errorEffect.playError()
                                }
                            }
                        }

                        Component.onDestruction: {
                            zxingFilter.decoder.enabledDecoders = QZXing.DecoderFormat_None
                        }
                    }

                    // Borda dourada com linha animada
                    Rectangle {
                        id: borderOverlay
                        anchors.fill: parent
                        radius: 30
                        color: "transparent"
                        border.width: 2
                        border.color: "#D4AF37"
                        clip: true

                        Rectangle {
                            id: scanningLine
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
                                NumberAnimation {
                                    from: 0
                                    to: borderOverlay.height - scanningLine.height
                                    duration: 1800
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: borderOverlay.height - scanningLine.height
                                    to: 0
                                    duration: 1800
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }

                // ── Texto informativo câmera ───────────────────────────────────
                Text {
                    id: txtDetectQrCode
                    text: appDataQrCode.dictionary["scannerPageDetectQrCode"] || ""
                    font.family: interRegular.name
                    font.pixelSize: 13
                    color: "#4B5563"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.6
                    lineHeightMode: Text.ProportionalHeight
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ── Feedback: Sucesso ─────────────────────────────────────────
                Item {
                    id: successEffect
                    width: parent.width
                    height: 180
                    visible: false
                    opacity: 0
                    scale: 0.6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: circle
                        width: 120
                        height: 120
                        radius: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "black"
                        border.color: "#D4AF37"
                        border.width: 2

                        Image {
                            source: "qrc:/images/images/checkmark.png"
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        anchors.top: circle.bottom
                        anchors.topMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                            text: appDataQrCode.dictionary["scannerPagerecognized"] || "Reconhecido"
                            font.family: playfairSemiBold.name
                            font.pixelSize: 22
                            color: "white"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: appDataQrCode.dictionary["scannerPageLoadContent"] || "A carregar conteúdo..."
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnim
                        running: false
                        NumberAnimation { to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        id: fadeIn
                        running: false
                        PropertyAnimation { target: successEffect; property: "opacity"; to: 1; duration: 150 }
                    }

                    function play() {
                        visible = true
                        fadeIn.start()
                        popAnim.start()
                        opacity = 1
                        scale = 1
                        itemEncontrado.restart()
                    }
                }

                // ── Feedback: Erro ────────────────────────────────────────────
                Item {
                    id: errorEffect
                    width: parent.width
                    height: 180
                    visible: false
                    opacity: 0
                    scale: 0.6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: circleError
                        width: 120
                        height: 120
                        radius: 60
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "black"
                        border.color: "red"
                        border.width: 2

                        Image {
                            source: "qrc:/images/images/close.png"
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        anchors.top: circleError.bottom
                        anchors.topMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                            text: appDataQrCode.dictionary["scannerErrorQrCode"] || "Não encontrado"
                            font.family: playfairSemiBold.name
                            font.pixelSize: 22
                            color: "red"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: appDataQrCode.dictionary["scannerComebackQrcode"] || "Tente novamente"
                            font.family: interRegular.name
                            font.pixelSize: 12
                            color: "#D4AF37"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    SequentialAnimation on scale {
                        id: popAnimError
                        running: false
                        NumberAnimation { to: 1.2; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        id: fadeInError
                        running: false
                        PropertyAnimation { target: errorEffect; property: "opacity"; to: 1; duration: 150 }
                    }

                    function playError() {
                        visible = true
                        fadeInError.start()
                        popAnimError.start()
                        opacity = 1
                        scale = 1
                        itemEncontradoError.restart()
                    }
                }

                // ══════════════════════════════════════════════════════════════
                //  SEPARADOR "OU"
                // ══════════════════════════════════════════════════════════════
                Row {
                    id: orDivider
                    width: parent.width - 40
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: (parent.width / 2) - 30
                        height: 1
                        color: "#4B5563"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: appDataQrCode.dictionary["ScannerPageOr"] || "OU"
                        font.family: interRegular.name
                        font.pixelSize: 13
                        font.letterSpacing: 1.32
                        font.capitalization: Font.AllUppercase
                        color: "#4B5563"
                    }

                    Rectangle {
                        width: (parent.width / 2) - 30
                        height: 1
                        color: "#4B5563"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // ══════════════════════════════════════════════════════════════
                //  SECÇÃO DO CÓDIGO MANUAL
                // ══════════════════════════════════════════════════════════════
                Column {
                    id: codeSection
                    width: parent.width
                    spacing: 16
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Título
                    Text {
                        text: appDataQrCode.dictionary["ScannerPageEnterCode"] || "INTRODUZA O CÓDIGO"
                        font.family: interMedium.name
                        font.pixelSize: 12
                        font.letterSpacing: 1.54
                        font.capitalization: Font.AllUppercase
                        color: "#D4AF37"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Caixas de dígitos
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                width: 60
                                height: 54
                                radius: 14
                                border.width: 2
                                border.color: root.currentIndex === index ? "#D4AF37" : "#2b2b2b"
                                color: "#1a1a1a"

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    text: root.number[index]
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 26
                                    font.family: interSemiBold.name
                                }
                            }
                        }
                    }

                    // Teclado numérico
                    Grid {
                        rows: 4
                        columns: 3
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: 12
                            delegate: Rectangle {
                                width: 90
                                height: 54
                                radius: 12
                                color: mouseAreaKey.pressed ? "#2a2a2a" : "#1a1a1a"
                                visible: index !== 9  // posição vazia (4ª fila, 1ª coluna)

                                property bool isZero:   index === 10
                                property bool isDelete: index === 11

                                Behavior on color {
                                    ColorAnimation { duration: 80 }
                                }

                                // Número ou zero
                                Text {
                                    visible: !parent.isDelete
                                    text: parent.isZero ? "0" : (index + 1).toString()
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 24
                                    font.family: interMedium.name
                                }

                                // Ícone delete
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
                                    enabled: index !== 9

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
                                            var temp2 = root.number
                                            temp2[root.currentIndex] = value
                                            root.number = temp2
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

                    // Espaço inferior
                    Item { width: 1; height: 20 }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  ECRÃ DO ITEM ENCONTRADO (getItem)
    // ══════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: getItem
        anchors.fill: parent
        visible: false
        color: "#111111"

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 40

            Column {
                id: contentColumn
                width: root.width
                spacing: 20

                // ─────────────────────────────
                // IMAGEM TOPO
                // ─────────────────────────────
                Item {
                    width: parent.width
                    height: 260

                    Image {
                        source: currentItem ? currentItem.coverUrlItem : ""
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

                // ─────────────────────────────
                // CONTEÚDO
                // ─────────────────────────────
                Column {
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    // Nome
                    Text {
                        text: currentItem ? currentItem.nameItem : ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 28
                        font.family: playfairSemiBold.name
                        color: "white"
                    }

                    // Descrição
                    Text {
                        text: currentItem ? currentItem.descriptionItem : ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.5
                        lineHeightMode: Text.ProportionalHeight

                        font.pixelSize: 14
                        font.family: interRegular.name

                        color: "#9CA3AF"
                    }

                    // PLAYER AUDIO
                    Rectangle {
                        id: recAudio
                        width: parent.width
                        height: 58
                        radius: 14

                        color: "#1A1A1A"
                        border.width: 1
                        border.color: "#2A2A2A"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 16

                            Rectangle {
                                id: playPauseButtonItem

                                width: 34
                                height: 34
                                radius: 17

                                color: "#2A2A2A"

                                property bool isPlaying: false

                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    source: playPauseButtonItem.isPlaying
                                            ? "qrc:/images/pouse.png"
                                            : "qrc:/images/images/PlayButton.png"

                                    width: playPauseButtonItem.isPlaying ? 18 : 12
                                    height: playPauseButtonItem.isPlaying ? 18 : 12

                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {
                                        playPauseButtonItem.isPlaying =!playPauseButtonItem.isPlaying
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - 70
                                height: 4
                                radius: 2
                                color: "#2A2A2A"
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: parent.width * 0.35
                                    height: parent.height
                                    radius: 2
                                    color: "#D4AF37"
                                }
                            }
                        }
                    }

                    // BOTÃO MAPA
                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 14

                        color: "#1A1A1A"

                        border.width: 1
                        border.color: "#D4AF37"

                        Text {
                            text: appDataQrCode.dictionary["scannerPageSeeMap"] || "VER NO MAPA"
                            anchors.centerIn: parent
                            font.pixelSize: 12
                            font.family: interMedium.name
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1.5
                            color: "#D4AF37"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // navegar mapa
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 40
                    }
                }
            }
        }

        // ─────────────────────────────
        // BOTÃO FECHAR
        // ─────────────────────────────
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
                    currentItem = null
                    camera.active = true
                    scannerContainer.visible = true
                    orDivider.visible = true
                    codeSection.visible = true
                    txtDetectQrCode.visible = true
                    successEffect.visible = false
                    errorEffect.visible = false
                }
            }
        }
    }

    // ── Aviso permissão negada ─────────────────────────────────────────────────
    Rectangle {
        id: permissionDenied
        anchors.fill: parent
        color: "#111111"
        visible: false

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "Permissão de câmera negada"
                color: "white"
                font.pixelSize: 16
                font.family: interRegular.name
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Ative nas definições do dispositivo"
                color: "#6b7280"
                font.pixelSize: 13
                font.family: interRegular.name
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Fontes ─────────────────────────────────────────────────────────────────
    FontLoader { id: playfairSemiBold; source: "qrc:/fonts/PlayfairDisplay-SemiBold.ttf" }
    FontLoader { id: playfairMedium;   source: "qrc:/fonts/PlayfairDisplay-Medium.ttf" }
    FontLoader { id: interRegular;     source: "qrc:/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interMedium;      source: "qrc:/fonts/Inter_18pt-Medium.ttf" }
    FontLoader { id: interSemiBold;    source: "qrc:/fonts/Inter_24pt-SemiBold.ttf" }
}
