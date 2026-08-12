import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtMultimedia


Item {
    id: header
    width: 400
    height: 600

    signal back()

    ListModel { id: strapiModelHomePageTour }

    property string linguaSelecionada: ""
    property int indexTours: appDataTour.tours ? appDataTour.tours.length : 0
    property int nextPageTours: 0
    property var selectedTourData: null
    property var dadosBrutos: null
    property string localMediaPath: ""
    property var appDataTour: ({})
    property bool showingTourPage: false

    // Primeira tour marcada isMainTour (a "visita completa ao museu"); se
    // houver mais do que uma marcada, só a primeira encontrada conta
    // (spec.md FR-001). Mostrada à parte, numa secção "Afixada" fixa no topo.
    property var mainTour: {
        var list = appDataTour.tours || []
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isMainTour === true) {
                return list[i]
            }
        }
        return null
    }

    // Restantes tours (todas, se nenhuma estiver marcada isMainTour).
    property var otherTours: {
        var list = appDataTour.tours || []
        if (!mainTour) return list
        var result = []
        for (var i = 0; i < list.length; i++) {
            if (list[i] !== mainTour) result.push(list[i])
        }
        return result
    }

    function handleBack() {
        // Se a TourPage estiver ativa (nextPageTours === 1), volta para a lista de tours
        if (nextPageTours === 1) {
            nextPageTours = 0;
            recTours.visible = true;
            return true; // Informa o Welcome que o evento de voltar foi resolvido aqui
        }
        return false; // Se já estiver na lista de tours, permite ao Welcome voltar para trás
    }


    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#E5E7EB"
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 20
            leftMargin: 20
            rightMargin: 20
        }

        RowLayout {
            spacing: 8

            Item {
                width: 150
                height: 32

                Canvas {
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
                    text: appDataTour.dictionary["toursButtonBack"]
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
                        alterarLingua.visible = true
                        imgEntity.visible = true
                    }
                }
            }
        }

        Text {
            text: appDataTour.dictionary["toursGuiedTour"]
            font.family: "Serif"
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: "#111827"
            Layout.fillWidth: true
        }

        Text {
            text: indexTours + " " + (appDataTour.dictionary["toursAvailableTours"] || "Tours Disponíveis")
            font.family: "Sans-Serif"
            font.pixelSize: 12
            color: "#9CA3AF"
            Layout.topMargin: 4
            Layout.fillWidth: true
        }
    }

    Rectangle {
        id: line
        width: parent.width
        height: 1
        color: "#9CA3AF"
        anchors.top: contentColumn.bottom
        anchors.topMargin: 20
    }

    Rectangle {
        id: recTours
        width: parent.width
        anchors {
            top: line.bottom
            bottom: parent.bottom
        }

        Rectangle {
            id: recRecurso
            width: parent.width - 40
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            ListView {
                id: listviewTour
                anchors.fill: parent
                anchors.topMargin: 20
                spacing: 15
                clip: true
                model: otherTours

                // Secção "Afixada" com a tour isMainTour, separada das
                // restantes por uma linha — o cartão usa exatamente o mesmo
                // conteúdo/layout do cartão normal, só a borda muda de cor.
                header: Component {
                    Column {
                        width: listviewTour.width
                        visible: !!mainTour
                        height: mainTour ? implicitHeight : 0
                        spacing: 15
                        bottomPadding: mainTour ? 15 : 0

                        Text {
                            text: appDataTour.dictionary["toursMainTourSectionLabel"] || "Afixada"
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.5
                            font.capitalization: Font.AllUppercase
                            color: "#D4AF37"
                        }

                        Rectangle {
                            id: mainTourCard
                            width: parent.width
                            height: mainTourCardContent.implicitHeight + 20
                            radius: 10
                            border.width: 2
                            border.color: "#D4AF37"
                            color: "white"

                            Row {
                                id: mainTourCardContent
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Image {
                                    source: mainTour ? mainTour.imageTour : ""
                                    width: 80
                                    height: 80
                                    fillMode: Image.PreserveAspectCrop
                                }

                                Column {
                                    spacing: 4
                                    width: parent.width - 100

                                    Text {
                                        text: mainTour ? mainTour.nameTour : ""
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: "#111827"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Row {
                                        spacing: 6
                                        Text {
                                            text: mainTour ? mainTour.timeTour : ""
                                            font.pixelSize: 11
                                            color: "#D4AF37"
                                        }
                                        Text {
                                            visible: !!(mainTour && mainTour.timeTour)
                                            text: "."
                                            font.pixelSize: 11
                                            color: "#4B5563"
                                        }
                                        Text {
                                            text: mainTour ? (mainTour.totalStops + " " + (mainTour.totalStops > 1 ? appDataTour.dictionary["tourStops"] : appDataTour.dictionary["tourPageStop"])) : ""
                                            font.pixelSize: 11
                                            color: "#4B5563"
                                        }
                                    }

                                    Text {
                                        text: mainTour ? mainTour.descriptionTour : ""
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
                                    selectedTourData = mainTour
                                    nextPageTours = 1
                                    recTours.visible = false
                                    isTourPageVisible = true
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#E5E7EB"
                        }
                    }
                }

                // Cartão no mesmo estilo visual da listagem de items em modo
                // lista da TourPage (imagem à esquerda, texto à direita),
                // conforme spec.md FR-002.
                delegate: Rectangle {
                    id: delegateRoot
                    width: recRecurso.width
                    height: 100
                    radius: 10
                    border.width: 1
                    border.color: mouseHandlerTour.containsMouse ? "#D4AF37" : "lightgrey"
                    color: "white"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Image {
                            source: modelData.imageTour
                            width: 80
                            height: 80
                            fillMode: Image.PreserveAspectCrop
                        }

                        Column {
                            spacing: 4
                            width: parent.width - 100

                            Text {
                                text: modelData.nameTour
                                font.pixelSize: 16
                                font.bold: true
                                color: "#111827"
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: 6
                                Text {
                                    text: modelData.timeTour
                                    font.pixelSize: 11
                                    color: "#D4AF37"
                                }
                                Text {
                                    visible: !!modelData.timeTour
                                    text: "."
                                    font.pixelSize: 11
                                    color: "#4B5563"
                                }
                                Text {
                                    text: modelData.totalStops + " " + (modelData.totalStops > 1 ? appDataTour.dictionary["tourStops"] : appDataTour.dictionary["tourPageStop"])
                                    font.pixelSize: 11
                                    color: "#4B5563"
                                }
                            }

                            Text {
                                text: modelData.descriptionTour
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
                        id: mouseHandlerTour
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            selectedTourData = modelData
                            nextPageTours = 1
                            recTours.visible = false

                            isTourPageVisible = true

                        }
                    }
                }
            }
        }
    }

    Loader {
        id: gameLoader
        anchors.fill: parent
        active: nextPageTours !== 0
        opacity: active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 500 }
        }

        sourceComponent: (nextPageTours === 1) ? tourPage : undefined
    }

    Component {
        id: tourPage
        TourPage {
            linguaSelecionadaTourPage: linguaSelecionada
            sessionId: root.sessionId
            onBack: {
                nextPageTours = 0
                recTours.visible = true
                isTourPageVisible = false
            }
            // Passamos o appData completo e o tour específico selecionado
            appDataTourPage: appDataTour
            tourInfo: selectedTourData
        }
    }
}
