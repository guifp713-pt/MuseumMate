import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: 60
    height: 60
    radius: 50
    color: "black"
    z: 9999

    Image {
        anchors.centerIn: parent
        width: 30
        height: 30
        source: "qrc:/images/images/qrCode.png"
    }
}


/*     CODIGO BARRA DE PROGRESSO

  Item {
    property int value: 0
    property real maxWidth: recProgress.width - 20

    Timer {
        id: timerProgress
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            value += 10
            if (value >= 100) {
                value = 100
                timerProgress.running = false
                console.log("Concluído")
            }
        }
    }

    Rectangle {
        anchors.fill: parent

        Text {
            id: txtMuseu
            text: value + "%"
            font.pixelSize: 88
            font.bold: true
            anchors.centerIn: parent
        }

        Rectangle {
            id: recProgress
            width: header.width - 40
            height: 50
            radius: 30
            color: "#f7f7f7"
            border.width: 0.5
            border.color: "#9CA3AF"
            anchors.top: txtMuseu.bottom
            anchors.topMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: recProgressGold
                width: (value / 100) * (parent.width - 20)
                height: 35
                radius: 30
                color: "#D4AF37"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10 // Mantém a margem

                // Comportamento suave
                Behavior on width {
                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
