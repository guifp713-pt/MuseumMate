import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window

import "AssistantHandler.js" as Assistant

/*
 * ChatIAPanel — painel de conversação do Assistente IA (feature 001-ai-museum-assistant).
 *
 * Extraído do stub inline `recChat`/`recChatText` que existia em HomePage.qml.
 * Mantém o comportamento original de arrastar-para-fechar e a animação de slide
 * via `anchors.bottomMargin`.
 *
 * O histórico vive apenas em memória (messagesModel) — nunca é escrito em
 * QtQuick.LocalStorage (FR-009). Como o painel é apenas escondido/mostrado
 * (deslizado) e nunca destruído, o histórico sobrevive a fechar/reabrir dentro
 * da mesma sessão da app.
 */
Rectangle {
    id: chatPanel

    // --- API pública do componente ---
    property string activeLanguage: ""   // idioma ativo da app (pt/en/es/fr) — FR-004
    property string sessionId: ""        // id de sessão reutilizado do AnalyticsHandler
    property alias messages: messagesModel
    property bool enabledLook: inputField.text.trim().length > 0 && !chatPanel.waitingForReply

    signal closeRequested()

    // Altura, em coordenadas locais, do teclado nativo do telemóvel quando
    // visível. No Android, `keyboardRectangle` vem em pixels físicos, por
    // isso é preciso dividir pelo devicePixelRatio para obter coordenadas QML.
    readonly property real keyboardHeight: Qt.inputMethod.visible
            ? Qt.inputMethod.keyboardRectangle.height / (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1)
            : 0

    // Mantém a última mensagem visível quando o teclado abre/fecha, já que a
    // área de mensagens encolhe/cresce com o espaço libertado pelo teclado.
    onKeyboardHeightChanged: messageList.positionViewAtEnd()

    radius: 24
    color: "#fafaf9"
    border.color: "#e8e4db"
    border.width: 1
    visible: anchors.bottomMargin > -parent.height

    // O Behavior é desativado enquanto o utilizador está a arrastar
    Behavior on anchors.bottomMargin {
        enabled: !dragAreaChat.isDragging
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    ListModel {
        id: messagesModel
    }

    // Contador para gerar ids locais únicos das mensagens
    property int messageCounter: 0

    function nextMessageId() {
        messageCounter += 1
        return "MSG_" + Date.now().toString(36) + "_" + messageCounter
    }

    /** Hora HH:MM mostrada por baixo do texto de cada balão. */
    function formatTime(date) {
        var h = date.getHours().toString()
        var m = date.getMinutes().toString()
        return (h.length < 2 ? "0" + h : h) + ":" + (m.length < 2 ? "0" + m : m)
    }

    /**
     * Mensagem de boas-vindas do assistente. Fica com status "welcome" (e não
     * "sent") de propósito: é texto local da UI, nunca foi um turno real da
     * conversa, por isso `buildHistory` exclui-a do contexto enviado ao servidor.
     */
    function showWelcomeMessage() {
        if (messagesModel.count > 0) return
        messagesModel.append({
                                 "msgId": nextMessageId(),
                                 "role": "assistant",
                                 "text": welcomeText(),
                                 "language": activeLanguage,
                                 "autoTranslated": false,
                                 "usedGeneralKnowledge": false,
                                 "status": "welcome",
                                 "errorKind": "",
                                 "time": formatTime(new Date()),
                                 "timestamp": new Date().toISOString()
                             })
    }

    Component.onCompleted: showWelcomeMessage()

    // Se o idioma mudar antes de haver conversa, a saudação acompanha-o
    onActiveLanguageChanged: {
        if (messagesModel.count === 1 && messagesModel.get(0).status === "welcome") {
            messagesModel.setProperty(0, "text", welcomeText())
            messagesModel.setProperty(0, "language", activeLanguage)
        } else {
            showWelcomeMessage()
        }
    }

    Rectangle {
        id: recGray
        width: 40
        height: 4
        radius: 2
        color: "#d1d5db"
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // --- ZONA DE ARRASTAR (HEADER) ---
    Item {
        width: parent.width
        height: 85
        anchors.top: parent.top

        MouseArea {
            id: dragAreaChat
            anchors.fill: parent

            property real startParentY: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                var mapped = mapToItem(chatPanel.parent, mouse.x, mouse.y)
                startParentY = mapped.y
                isDragging = true
            }

            onPositionChanged: (mouse) => {
                if (isDragging) {
                    var mapped = mapToItem(chatPanel.parent, mouse.x, mouse.y)
                    var deltaY = mapped.y - startParentY

                    // Só permite arrastar para baixo (valores positivos de deltaY)
                    if (deltaY > 0) {
                        chatPanel.anchors.bottomMargin = -deltaY
                    } else {
                        chatPanel.anchors.bottomMargin = 0
                    }
                }
            }

            onReleased: (mouse) => {
                isDragging = false
                var mapped = mapToItem(chatPanel.parent, mouse.x, mouse.y)
                var deltaY = mapped.y - startParentY

                // Se arrastou mais de 120 pixeis para baixo, fecha o chat
                if (deltaY > 120) {
                    chatPanel.closeRequested()
                } else {
                    // Caso contrário, faz o "snap back"
                    chatPanel.anchors.bottomMargin = 0
                }
            }
        }
    }

    // --- CABEÇALHO: avatar + identidade à esquerda, fechar à direita ---
    Item {
        id: rowAi
        height: 50
        anchors.top: recGray.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        Rectangle {
            id: avatarWrapper
            width: 36
            height: 36
            radius: 18
            color: "#1fD4AF37"
            border.color: "#59D4AF37"
            border.width: 1
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: imgStarsAi
                width: 16
                height: 16
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                source: "qrc:/images/images/sparkle.png"
            }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: "#22c55e"
                border.color: "#fafaf9"
                border.width: 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }

        Column {
            id: colTextAi
            anchors.left: avatarWrapper.right
            anchors.leftMargin: 10
            anchors.right: recbackAI.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Museum Mate AI"
                font.pixelSize: 15
                font.bold: true
                font.family: "Georgia"
                color: "#1a1a1a"
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "● " + chatPanel.onlineText()
                font.pixelSize: 10
                font.family: "Sans-Serif"
                color: "#22c55e"
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Rectangle {
            id: recbackAI
            width: 32
            height: 32
            radius: 16
            color: "#1a1a1a"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "x"
                font.pixelSize: 13
                color: "white"
                font.family: "Sans-Serif"
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: chatPanel.closeRequested()
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: "#e8e4db"
        anchors.top: rowAi.bottom
        anchors.topMargin: 10
        id: headerSeparator
    }

    // --- LISTA DE MENSAGENS ---
    Rectangle {
        id: messagesBackground
        color: "#f4f1eb"
        anchors.top: headerSeparator.bottom
        anchors.bottom: inputArea.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 1
        anchors.rightMargin: 1

        ListView {
            id: messageList
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            spacing: 12
            model: messagesModel

            // Mantém a vista sempre na mensagem mais recente
            onCountChanged: positionViewAtEnd()

            delegate: Item {
                id: messageRow
                width: messageList.width
                height: bubble.height + (errorRow.visible ? errorRow.height + 6 : 0)

                // Largura máxima do balão: nunca ultrapassa a área visível,
                // seja qual for o ecrã (evita texto a sair da tela).
                readonly property real maxBubbleWidth: messageList.width * 0.78

                // Medidor invisível, sem largura imposta: dá o comprimento
                // natural (uma linha) do texto, usado só para decidir se o
                // balão encolhe ao conteúdo ou cresce até maxBubbleWidth. Ao
                // contrário do Text visível, não depende da largura do
                // balão, por isso não cria um ciclo de bindings.
                Text {
                    id: textMeasure
                    text: model.text
                    font.pixelSize: 13
                    font.family: "Sans-Serif"
                    visible: false
                }

                // Avatar: sparkle para o assistente, perfil para o visitante
                Rectangle {
                    id: avatar
                    width: 28
                    height: 28
                    radius: 14
                    anchors.top: parent.top
                    anchors.left: model.role === "visitor" ? undefined : parent.left
                    anchors.right: model.role === "visitor" ? parent.right : undefined
                    color: model.role === "visitor" ? "#1a1a1a" : "#26D4AF37"
                    border.width: 1
                    border.color: model.role === "visitor" ? "#2a2a2a" : "#59D4AF37"

                    Image {
                        width: 14
                        height: 14
                        anchors.centerIn: parent
                        fillMode: Image.PreserveAspectFit
                        source: model.role === "visitor"
                                ? "qrc:/images/images/iconProfile.png"
                                : "qrc:/images/images/sparkle.png"
                    }
                }

                Rectangle {
                    id: bubble
                    anchors.top: parent.top
                    // Encolhe ao conteúdo (medido por textMeasure, sem depender
                    // da própria largura do balão) mas nunca ultrapassa
                    // maxBubbleWidth — por isso o texto nunca sai do ecrã.
                    width: Math.min(messageRow.maxBubbleWidth, textMeasure.implicitWidth + 28)
                    height: bubbleColumn.implicitHeight + 20
                    radius: 16
                    color: model.role === "visitor" ? "#1a1a1a" : "white"
                    border.width: 1
                    border.color: model.role === "visitor" ? "#2a2a2a" : "#e8e4db"
                    anchors.right: model.role === "visitor" ? avatar.left : undefined
                    anchors.left: model.role === "visitor" ? undefined : avatar.right
                    anchors.leftMargin: model.role === "visitor" ? 0 : 8
                    anchors.rightMargin: model.role === "visitor" ? 8 : 0

                    Column {
                        id: bubbleColumn
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 28
                        spacing: 4

                        Text {
                            width: parent.width
                            text: model.text
                            wrapMode: Text.Wrap
                            lineHeight: 1.3
                            font.pixelSize: 13
                            font.family: "Sans-Serif"
                            color: model.role === "visitor" ? "white" : "#1a1a1a"
                        }

                        // Indicador de tradução automática (FR-015)
                        Text {
                            visible: model.role === "assistant" && model.autoTranslated
                            text: chatPanel.translationNoticeText()
                            font.pixelSize: 10
                            font.italic: true
                            font.family: "Sans-Serif"
                            color: "#6b7280"
                        }

                        // Indicador de resposta por conhecimento geral da IA, fora do catálogo
                        // (specs/003-assistant-web-fallback, FR-007). Distinto do indicador de
                        // tradução acima — ambos podem aparecer juntos.
                        Text {
                            visible: model.role === "assistant" && model.usedGeneralKnowledge
                            text: chatPanel.knowledgeNoticeText()
                            font.pixelSize: 10
                            font.italic: true
                            font.family: "Sans-Serif"
                            color: "#6b7280"
                        }

                        // Hora da mensagem
                        Text {
                            width: parent.width
                            text: model.time
                            font.pixelSize: 9
                            font.family: "Sans-Serif"
                            horizontalAlignment: model.role === "visitor" ? Text.AlignRight : Text.AlignLeft
                            color: model.role === "visitor" ? "#59FFFFFF" : "#9ca3af"
                        }
                    }
                }

                // Estado de erro da própria mensagem do visitante (T021/T022).
                // O contrato diz explicitamente para NÃO acrescentar um turno de
                // assistente partido à conversa: o erro é mostrado agarrado à
                // mensagem que falhou, com a opção de repetir o envio.
                Row {
                    id: errorRow
                    visible: model.role === "visitor" && model.status === "error"
                    anchors.top: bubble.bottom
                    anchors.topMargin: 6
                    anchors.right: parent.right
                    spacing: 8

                    Text {
                        text: chatPanel.errorText(model.errorKind)
                        font.pixelSize: 10
                        font.family: "Sans-Serif"
                        color: "#b91c1c"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: chatPanel.retryText()
                        font.pixelSize: 10
                        font.family: "Sans-Serif"
                        font.underline: true
                        color: "#1a1a1a"
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8   // alvo de toque maior que o texto
                            onClicked: chatPanel.retryMessage(index)
                        }
                    }
                }
            }

            // Indicador de escrita + sugestões iniciais acompanham o fim da lista
            footer: Column {
                width: messageList.width
                spacing: 10
                topPadding: messageList.count > 0 ? 12 : 0

                // --- INDICADOR DE ESCRITA ---
                Row {
                    id: typingIndicator
                    visible: chatPanel.waitingForReply
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: "#26D4AF37"
                        border.color: "#59D4AF37"
                        border.width: 1

                        Image {
                            width: 14
                            height: 14
                            anchors.centerIn: parent
                            fillMode: Image.PreserveAspectFit
                            source: "qrc:/images/images/sparkle.png"
                        }
                    }

                    Rectangle {
                        // Larga o suficiente para o texto "Ainda a pensar..." quando a
                        // heurística de tempo decorrido dispara (research.md §6);
                        // no estado normal (3 pontos) mantém a largura original.
                        width: chatPanel.longWaitLikely ? waitLabel.implicitWidth + 24 : 56
                        height: 34
                        radius: 16
                        color: "white"
                        border.color: "#e8e4db"
                        border.width: 1

                        Behavior on width { NumberAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: !chatPanel.longWaitLikely

                            Repeater {
                                model: 3

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: "#D4AF37"

                                    SequentialAnimation on opacity {
                                        running: typingIndicator.visible && !chatPanel.longWaitLikely
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: index * 150 }
                                        NumberAnimation { to: 1.0; duration: 300 }
                                        NumberAnimation { to: 0.3; duration: 300 }
                                        PauseAnimation { duration: 300 - index * 150 }
                                    }
                                }
                            }
                        }

                        // Estado "ainda a pensar..." (specs/003-assistant-web-fallback):
                        // heurística por tempo decorrido, não um sinal real do
                        // servidor — ver chatPanel.longWaitLikely/longWaitTimer.
                        Text {
                            id: waitLabel
                            anchors.centerIn: parent
                            visible: chatPanel.longWaitLikely
                            text: chatPanel.longWaitNoticeText()
                            font.pixelSize: 11
                            font.italic: true
                            font.family: "Sans-Serif"
                            color: "#6b7280"
                        }
                    }
                }

                // --- SUGESTÕES (só enquanto a conversa não começou) ---
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: messagesModel.count <= 1 && !chatPanel.waitingForReply

                    Repeater {
                        model: chatPanel.suggestionTexts()

                        Rectangle {
                            width: suggestionLabel.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: "white"
                            border.color: "#e8e4db"
                            border.width: 1

                            Text {
                                id: suggestionLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 11
                                font.family: "Sans-Serif"
                                color: "#1a1a1a"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: inputField.text = modelData
                            }
                        }
                    }
                }
            }
        }
    }

    // --- ZONA DE INPUT ---
    Rectangle {
        id: inputArea
        width: parent.width
        height: 96
        anchors.bottom: parent.bottom
        // Sobe acima do teclado nativo quando este está visível, para o
        // visitante ver sempre o texto que está a escrever.
        anchors.bottomMargin: 1 + chatPanel.keyboardHeight
        color: "white"

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        // Separador superior da barra de escrita
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#e8e4db"
        }

        Rectangle {
            id: inputRow
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: sendButton.left
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            height: 44
            radius: 22
            color: "#f4f1eb"
            border.color: "#e8e4db"
            border.width: 1

            TextField {
                id: inputField
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: chatPanel.inputPlaceholderText()
                font.pixelSize: 13
                font.family: "Sans-Serif"
                color: "#1a1a1a"
                background: Item {}
                onAccepted: chatPanel.sendCurrentMessage()
            }
        }

        Rectangle {
            id: sendButton
            width: 40
            height: 40
            radius: 20
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: inputRow.verticalCenter
            color: enabledLook ? "#D4AF37" : "#e8e4db"
            opacity: enabledLook ? 1.0 : 0.6

            Image {
                width: 16
                height: 16
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                source: enabledLook ? "qrc:/images/images/send_black.png" : "qrc:/images/images/send_IA.png"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: chatPanel.sendCurrentMessage()
            }
        }

        Text {
            id: aiNotice
            anchors.top: inputRow.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !emptyHintTimer.running
            text: chatPanel.aiNoticeText()
            font.pixelSize: 10
            font.family: "Sans-Serif"
            color: "#9CA3AF"
        }

        Text {
            id: emptyHint
            anchors.top: inputRow.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: emptyHintTimer.running
            text: chatPanel.emptyMessageHintText()
            font.pixelSize: 10
            font.family: "Sans-Serif"
            color: "#b91c1c"
        }

        Timer {
            id: emptyHintTimer
            interval: 2500
            repeat: false
        }
    }

    // --- TEXTOS LOCALIZADOS ---
    // Textos da própria UI do assistente. Ficam no componente porque não existem
    // como chaves de dictionary no Strapi para esta feature.
    function onlineText() {
        switch (activeLanguage) {
        case "en": return "Online · replies in seconds"
        case "es": return "En línea · responde en segundos"
        case "fr": return "En ligne · répond en quelques secondes"
        default:   return "Online · responde em segundos"
        }
    }

    function welcomeText() {
        switch (activeLanguage) {
        case "en": return "Hello! I am Museum Mate AI, your digital companion. Ask me about our collections, recommended tours, opening hours or how to navigate the museum."
        case "es": return "¡Hola! Soy Museum Mate AI, tu compañero digital. Pregúntame sobre nuestras colecciones, tours recomendados, horarios o cómo moverte por el museo."
        case "fr": return "Bonjour ! Je suis Museum Mate AI, votre compagnon numérique. Posez-moi des questions sur nos collections, les visites recommandées, les horaires ou comment vous orienter."
        default:   return "Olá! Sou o Museum Mate AI, o teu companheiro digital. Pergunta-me sobre as nossas coleções, Visitas Guiadas recomendadas, horários de abertura ou como navegar pelo museu."
        }
    }

    function suggestionTexts() {
        switch (activeLanguage) {
        case "en": return ["Opening hours", "Recommended tour", "Where is Room A?"]
        case "es": return ["Horario de apertura", "Tour recomendado", "¿Dónde está la Sala A?"]
        case "fr": return ["Heures d'ouverture", "Visite recommandée", "Où est la Salle A ?"]
        default:   return ["Horário de abertura", "Tour recomendada", "Onde fica a Sala A?"]
        }
    }

    function aiNoticeText() {
        switch (activeLanguage) {
        case "en": return "Messages are processed by AI"
        case "es": return "Los mensajes son procesados por IA"
        case "fr": return "Les messages sont traités par IA"
        default:   return "As mensagens são processadas por IA"
        }
    }

    function translationNoticeText() {
        switch (activeLanguage) {
        case "en": return "Automatic translation"
        case "es": return "Traducción automática"
        case "fr": return "Traduction automatique"
        default:   return "Tradução automática"
        }
    }

    // Indicador de resposta gerada com conhecimento geral da IA, fora do
    // catálogo do museu (specs/003-assistant-web-fallback, FR-007)
    function knowledgeNoticeText() {
        switch (activeLanguage) {
        case "en": return "AI general-knowledge answer (outside the museum catalog)"
        case "es": return "Respuesta con conocimiento general de la IA (fuera del catálogo)"
        case "fr": return "Réponse basée sur les connaissances générales de l'IA (hors catalogue)"
        default:   return "Resposta com conhecimento geral da IA (fora do catálogo)"
        }
    }

    // Estado "a pensar mais um pouco..." do indicador de escrita, heurística por
    // tempo decorrido (specs/003-assistant-web-fallback, research.md §6): sinaliza
    // o caminho mais lento de 2 chamadas (catálogo + fallback de conhecimento).
    function longWaitNoticeText() {
        switch (activeLanguage) {
        case "en": return "Still thinking…"
        case "es": return "Sigo pensando…"
        case "fr": return "Je réfléchis encore…"
        default:   return "Ainda a pensar…"
        }
    }

    function inputPlaceholderText() {
        switch (activeLanguage) {
        case "en": return "Ask about the museum..."
        case "es": return "Pregunta sobre el museo..."
        case "fr": return "Posez une question sur le musée..."
        default:   return "Pergunte sobre o museu..."
        }
    }

    // Os dois estados de erro são deliberadamente distintos (FR-008): sem rede
    // é acionável pelo visitante, serviço indisponível não é.
    function errorText(kind) {
        if (kind === "network") {
            switch (activeLanguage) {
            case "en": return "No internet connection."
            case "es": return "Sin conexión a Internet."
            case "fr": return "Pas de connexion Internet."
            default:   return "Sem ligação à Internet."
            }
        }
        switch (activeLanguage) {
        case "en": return "Assistant unavailable."
        case "es": return "Asistente no disponible."
        case "fr": return "Assistant indisponible."
        default:   return "Assistente indisponível."
        }
    }

    function retryText() {
        switch (activeLanguage) {
        case "en": return "Try again"
        case "es": return "Reintentar"
        case "fr": return "Réessayer"
        default:   return "Tentar de novo"
        }
    }

    function emptyMessageHintText() {
        switch (activeLanguage) {
        case "en": return "Type a question first."
        case "es": return "Escribe una pregunta primero."
        case "fr": return "Écrivez d'abord une question."
        default:   return "Escreva primeiro uma pergunta."
        }
    }

    // --- ENVIO ---

    // Pedido em curso, para o Timer de timeout poder cancelá-lo.
    property var pendingRequest: null
    property bool waitingForReply: false

    Timer {
        id: timeoutTimer
        interval: Assistant.REQUEST_TIMEOUT_MS
        repeat: false
        onTriggered: {
            if (chatPanel.pendingRequest) chatPanel.pendingRequest.abort()
        }
    }

    // Heurística "ainda a pensar..." (specs/003-assistant-web-fallback,
    // research.md §6): o servidor não avisa o cliente a meio do pedido quando
    // aciona o fallback de conhecimento (topologia pedido/resposta único, sem
    // streaming), por isso isto é só uma estimativa por tempo decorrido — depois
    // da latência típica de uma resposta só-catálogo (~8s), assume-se que o
    // caminho mais lento de 2 chamadas está em curso e troca-se o indicador de escrita.
    property bool longWaitLikely: false

    Timer {
        id: longWaitTimer
        interval: 8000
        repeat: false
        onTriggered: {
            chatPanel.longWaitLikely = true
        }
    }

    // Índice, no modelo, da mensagem do visitante que está em voo — é nela que o
    // erro é marcado e é dela que parte o retry.
    property int pendingIndex: -1

    // Número máximo de turnos de contexto enviados (FR-014). O servidor volta a
    // limitar ao mesmo valor; manter o corte também aqui evita enviar pela rede
    // um histórico que iria de qualquer forma ser descartado.
    readonly property int maxHistoryTurns: 20

    /**
     * Constrói o histórico a enviar: os turnos anteriores a `upToIndex`, do mais
     * antigo para o mais recente. Mensagens em erro ou ainda por responder são
     * excluídas — nunca chegaram a fazer parte da conversa que o modelo viu.
     */
    function buildHistory(upToIndex) {
        var turns = []
        for (var i = 0; i < upToIndex && i < messagesModel.count; i++) {
            var m = messagesModel.get(i)
            if (m.status !== "sent") continue
            turns.push({ "role": m.role, "text": m.text })
        }
        return turns.slice(-maxHistoryTurns)
    }

    /** Envia (ou reenvia) a mensagem que está no índice `index` do modelo. */
    function dispatch(index) {
        var entry = messagesModel.get(index)

        pendingIndex = index
        waitingForReply = true
        longWaitLikely = false
        timeoutTimer.restart()
        longWaitTimer.restart()

        pendingRequest = Assistant.askAssistant(
                    entry.text,
                    activeLanguage,
                    sessionId,
                    buildHistory(index),
                    function(result) { chatPanel.onAssistantReply(result) },
                    function() { chatPanel.onAssistantFailure("network") },
                    function() { chatPanel.onAssistantFailure("service") })
    }

    function sendCurrentMessage() {
        var text = inputField.text

        // Não submete mensagens vazias/só com espaços (guard local, sem ida à
        // rede): em vez disso pede ao visitante que escreva uma pergunta.
        if (!text || text.trim().length === 0) {
            emptyHintTimer.restart()
            return
        }

        // Evita envios sobrepostos enquanto se espera resposta
        if (waitingForReply) {
            return
        }

        messagesModel.append({
                                 "msgId": nextMessageId(),
                                 "role": "visitor",
                                 "text": text.trim(),
                                 "language": activeLanguage,
                                 "autoTranslated": false,
                                 "usedGeneralKnowledge": false,
                                 "status": "sending",
                                 "errorKind": "",
                                 "time": formatTime(new Date()),
                                 "timestamp": new Date().toISOString()
                             })

        inputField.text = ""
        dispatch(messagesModel.count - 1)
    }

    /**
     * Repete o envio de uma mensagem que falhou (edge case do spec: o visitante
     * pode tentar de novo quando a ligação voltar). Reutiliza o mesmo texto,
     * idioma ativo e histórico, voltando a pôr a mensagem em "sending".
     */
    function retryMessage(index) {
        if (waitingForReply) return
        if (index < 0 || index >= messagesModel.count) return
        if (messagesModel.get(index).status !== "error") return

        messagesModel.setProperty(index, "errorKind", "")
        messagesModel.setProperty(index, "status", "sending")
        dispatch(index)
    }

    function finishRequest() {
        timeoutTimer.stop()
        longWaitTimer.stop()
        longWaitLikely = false
        pendingRequest = null
        waitingForReply = false
        pendingIndex = -1
    }

    // Uma recusa por estar fora de âmbito (`result.onTopic === false`) é uma
    // resposta normal e preenchida, não uma falha: é acrescentada como qualquer
    // outra mensagem do assistente, sem estilo de erro. Por isso `onTopic` não é
    // consultado aqui nem guardado no modelo.
    function onAssistantReply(result) {
        if (pendingIndex >= 0 && pendingIndex < messagesModel.count) {
            messagesModel.setProperty(pendingIndex, "status", "sent")
        }
        finishRequest()

        messagesModel.append({
                                 "msgId": nextMessageId(),
                                 "role": "assistant",
                                 "text": result.answer,
                                 "language": activeLanguage,
                                 // Indicador de tradução automática (FR-015)
                                 "autoTranslated": result.autoTranslated === true,
                                 // Indicador de fonte externa (specs/003-assistant-web-fallback, FR-007)
                                 "usedGeneralKnowledge": result.usedGeneralKnowledge === true,
                                 "status": "sent",
                                 "errorKind": "",
                                 "time": formatTime(new Date()),
                                 "timestamp": new Date().toISOString()
                             })
    }

    /**
     * Falha do pedido: marca a mensagem do visitante como em erro, com a
     * distinção entre "sem Internet" e "serviço indisponível" (FR-008).
     * Nenhum turno de assistente é acrescentado — a conversa não fica com uma
     * resposta partida no meio.
     */
    function onAssistantFailure(kind) {
        console.warn("[ChatIAPanel] Pedido falhou:", kind)

        if (pendingIndex >= 0 && pendingIndex < messagesModel.count) {
            messagesModel.setProperty(pendingIndex, "errorKind", kind)
            messagesModel.setProperty(pendingIndex, "status", "error")
        }

        finishRequest()
    }
}
