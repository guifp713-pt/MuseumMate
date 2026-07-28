import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtMultimedia
import QZXing

Item {
    id: welcomeItem
    width: 400
    height: 600

    // --- PROPRIEDADES DE ESTADO ---
    signal back()
        property int nextPageWelcome: 0
        property string linguaEscolhidaWelcome: ""
        property var appDataWelcome: ({})
        property var dictionaryWelcome: appDataWelcome.dictionary || {}

        function handleBack() {
            if (gameLoader.active && gameLoader.item && typeof gameLoader.item.handleBack === "function") {
                if (gameLoader.item.handleBack()) {
                    return true;
                }
            }

            if (nextPageWelcome !== 0) {
                nextPageWelcome = 0;
                return true; // Evento consumido com sucesso
            }

            return false;
        }

    Item {
        id: itemImgEntity
        width: welcomeItem.width
        height: parent.height / 2 - 100
        visible: nextPageWelcome === 0 ? true : false

        Image {
            id : imgEntity
            anchors.fill: parent
            source: appDataWelcome.entities[0].imageEntityUrl
            fillMode: Image.PreserveAspectCrop

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent"}
                    GradientStop { position: 0.5; color: "transparent"}
                    GradientStop { position: 0.8; color: "#CCFFFFFF" }
                    // GradientStop { position: 0.9; color: "white" }
                    GradientStop { position: 1.0; color: "white" }
                }
            }
        }
    }

    Column {
        id: columnPrincipal
        width: parent.width * 0.9
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height / 2) - 150
        spacing: 15
        visible: nextPageWelcome === 0 ? true : false

        Item {
            width: parent.width * 0.7
            height: txtWelcome.contentHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: txtWelcome
                width: parent.width
                text: appDataWelcome.dictionary["welcomeText"]
                wrapMode: Text.WordWrap
                font.family: playfairSemiBold.name
                font.pixelSize: 25
                font.weight: Font.DemiBold
                font.letterSpacing: 2
                color: "#1a1a1a"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Repeater que usa o Array de entidades diretamente
        Repeater {
            model: appDataWelcome.entities
            delegate: Text {
                text: modelData.descriptionEntity || ""
                width: columnPrincipal.width
                font.family: interRegular.name
                font.pixelSize: 14
                lineHeight: 1.6
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#6b7280"
            }
        }
    }

    // Caixa de Informações (Duração, Wi-Fi, etc)
    Rectangle {
        id: recInfo
        width: parent.width - 40
        height: 80
        color: "#f7f7f7"
        border.width: 1
        radius: 10
        border.color: "#D3D3D3"
        anchors.top: columnPrincipal.bottom
        anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        visible: nextPageWelcome === 0 ? true : false

        Rectangle {
            id: informacoes2
            width: 18
            height: 18
            radius: 150
            border.width: 2
            border.color: "#D4AF37"
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 20

            Text {
                text: "i"
                font.bold: true
                color: "#D4AF37"
                font.pixelSize: 10
                anchors.centerIn: parent
            }
        }

        Column {
            anchors.left: informacoes2.right
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 5

            Text {
                text: appDataWelcome.dictionary["welcomeInfoVisitTitle"]
                font.pixelSize: 13
                font.family: interSemiBold.name
                color: "black"
            }

            Text {
                text: appDataWelcome.dictionary["welcomeInfoTime"] + " " + appDataWelcome.dictionary["welcomeAverageDuration"]
                font.pixelSize: 13
                font.family: interRegular.name
                color: "#6b7280"
            }

            Text {
                text: appDataWelcome.dictionary["welcomeWi-fi"]
                font.pixelSize: 13
                font.family: interRegular.name
                color: "#6b7280"
            }
        }
    }

    // Coluna de Botões de Ação
    Column {
        id: colbuttons
        anchors.top: recInfo.bottom
        anchors.topMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        visible: nextPageWelcome === 0 ? true : false

        // Iniciar Visita
        Rectangle {
            width: welcomeItem.width - 40
            height: 60
            radius: 10
            color: "black"

            Row {
                anchors.centerIn: parent
                spacing: 20
                Image { source: "qrc:/images/images/icons8-map-24.png" }
                Text {
                    text: appDataWelcome.dictionary["welcomeButtonstartvisit"]
                    font.family: interRegular.name
                    font.pixelSize: 15
                    font.bold: true; color: "white"; font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    nextPageWelcome = 1
                }
            }
        }

        // Visita Guiada (Tours)
        Rectangle {
            width: welcomeItem.width - 40
            height: 50
            color: "white"; radius: 10; border.width: 1; border.color: "#D4AF37"

            Row {
                anchors.centerIn: parent
                spacing: 20
                Image { source: "qrc:/images/images/headphone.png" }
                Text {
                    text: appDataWelcome.dictionary["welcomeButtonsGuiedTour"]
                    font.family: interRegular.name
                    font.pixelSize: 15
                    color: "#D4AF37"; font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked:  {
                    nextPageWelcome = 2
                }
            }
        }
    }

    Text {
        text: appDataWelcome.dictionary["welcomeAvailableLanguages"]
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: colbuttons.bottom
        anchors.topMargin: 15
        font.family: interRegular.name; font.pixelSize: 11
        color: "#9ca3af"; horizontalAlignment: Text.AlignHCenter
        visible: nextPageWelcome === 0
    }

    // GlobalQrButton {
    //     id: qrButton
    //     x: 20
    //     y: welcomeItem.height - height - 20
    //     visible: nextPageWelcome === 0 ? true : false

    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             nextPageWelcome = 3
    //             // colbuttons.visible = false
    //             // qrButton.visible = false
    //         }
    //     }
    // }

    Rectangle {
        id: alterarLingua
        width: 50
        height: 50
        radius: 150
        border.width: 1
        border.color: "#D4AF37"
        color: "transparent"
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20

        Text {
            id: txtLanguage
            text: linguaEscolhidaWelcome
            font.family: interSemiBold.name
            font.pixelSize: 14
            font.capitalization: Font.AllUppercase
            color: "#D4AF37"
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                back()
            }
        }
    }

    // --- NAVEGAÇÃO INTERNA (LOADER) ---
    Loader {
        id: gameLoader
        anchors.fill: parent
        active: nextPageWelcome !== 0
        opacity: active ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 500 } }

        sourceComponent: {
            if (nextPageWelcome === 1) return homepage
            if (nextPageWelcome === 2) return toursPage
            if (nextPageWelcome === 3) return qrScannerPage
            return null
        }
    }

    Component {
        id: homepage

        HomePage {
            linguaEscolhidaHome: linguaEscolhidaWelcome
            onBack: nextPageWelcome = 0
            appDataHomePage: appDataWelcome
        }
    }
    Component {
        id: toursPage

        Tours {
            linguaSelecionada: linguaEscolhidaWelcome
            appDataTour: appDataWelcome
            onBack: nextPageWelcome = 0
        }
    }

    Component { id: qrScannerPage
        ScannerPage {
            linguaSelecionadaQrCode: linguaEscolhidaWelcome
            appDataQrCode: appDataWelcome
            onBack: nextPageWelcome = 0
        }
    }

    // --- FONTES ---
    FontLoader { id: playfairSemiBold; source: "qrc:/fonts/PlayfairDisplay-SemiBold.ttf" }
    FontLoader { id: interRegular; source: "qrc:/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interSemiBold; source: "qrc:/fonts/Inter_24pt-SemiBold.ttf" }
}
