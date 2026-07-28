import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: 50
    height: 50
    radius: 50
    color: "black"
    z: 9999

    Image {
        anchors.centerIn: parent
        width: 20
        height: 20
        source: "qrc:/images/images/chat.png"
    }
}
