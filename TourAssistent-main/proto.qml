import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtMultimedia
import "ApiHandler.js" as AH

Item {
    width: 400
    height: 400

    property int valueBottomBar: 0

    Rectangle {
        id: itemTotal
        width: parent.width
        height: 60
        border.width: 1
        border.color: "#E8E8E8"
        anchors.bottom: parent.bottom

        Row {
            width: parent.width
            height: parent.height

            Rectangle {
                width: parent.width / 3
                height: parent.height
                border.width: 1
                border.color: "#E8E8E8"
                color: "transparent"

                Column {
                    spacing: 5
                    width: parent.width
                    anchors.centerIn: parent

                    Image {
                        id: imgBottomBar
                        width: 24
                        height: 24
                        source: valueBottomBar === 0 ? "file:///C:/Users/guilh/Documents/untitled5/images/iconMapGold.png" : "file:///C:/Users/guilh/Documents/untitled5/images/iconMapGray.png"
                        anchors.horizontalCenter: parent.horizontalCenter
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: "PLANTA"
                        font.pixelSize: 13
                        font.letterSpacing: 1.0
                        font.capitalization: Font.AllUppercase
                        color: valueBottomBar === 0 ? "#D4AF37" : "#9CA3AF"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        valueBottomBar = 0
                    }
                }
            }

            Rectangle {
                width: parent.width / 3
                height: parent.height
                border.width: 1
                border.color: "#E8E8E8"
                color: "transparent"

                Column {
                    spacing: 5
                    width: parent.width
                    anchors.centerIn: parent

                    Image {
                        id: imgBottomBar2
                        width: 24
                        height: 24
                        source: valueBottomBar === 1 ? "file:///C:/Users/guilh/Documents/untitled5/images/icons8-openbook_gold.png" : "file:///C:/Users/guilh/Documents/untitled5/images/icons8-openboo_Gray.png"
                        anchors.horizontalCenter: parent.horizontalCenter
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: "VISITAS"
                        font.pixelSize: 13
                        font.letterSpacing: 1.0
                        font.capitalization: Font.AllUppercase
                        color: valueBottomBar === 1 ? "#D4AF37" : "#9CA3AF"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        valueBottomBar = 1
                    }
                }
            }

            Rectangle {
                width: parent.width / 3
                height: parent.height
                border.width: 1
                border.color: "#E8E8E8"
                color: "transparent"

                Column {
                    spacing: 0
                    width: parent.width
                    anchors.centerIn: parent

                    Rectangle {
                        id: alterarLingua
                        width: 30
                        height: 30
                        radius: 150
                        border.width: 0.5
                        border.color: valueBottomBar === 2 ? "#D4AF37" : "#9CA3AF"
                        color: "transparent"
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            id: txtLanguage
                            text: "PT"
                            font.family: interSemiBold.name
                            font.pixelSize: 12
                            font.capitalization: Font.AllUppercase
                            color: valueBottomBar === 2 ? "#D4AF37" : "#9CA3AF"
                            anchors.centerIn: parent
                        }
                    }

                    Text {
                        text: "IDIOMA"
                        font.pixelSize: 13
                        font.letterSpacing: 1.0
                        font.capitalization: Font.AllUppercase
                        color: valueBottomBar === 2 ? "#D4AF37" : "#9CA3AF"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        valueBottomBar = 2
                    }
                }
            }
        }
    }
}


/*
http://10.82.253.27/:1337/api/entidades?locale=pt&
populate[dictionaries]=true
&populate[imageEntity]=true
&populate[audio]=true
&populate[tours][populate][imageTour]=true
&populate[tours][populate][items][populate][coverItem]=true
&populate[tours][populate][items][populate][audioItem]=true
&populate[maps][populate][imageMap]=true
&populate[maps][populate][areas][populate][imageArea]=true
&populate[maps][populate][areas][populate][audioArea]=true
&populate[maps][populate][areas][populate][items][populate][coverItem]=true
&populate[maps][populate][areas][populate][items][populate][audioItem]=true
&populate[maps][populate][areas][populate][items][populate][qrCodeImage]=true

PASSOS PARA adb:
1- cd C:\Users\guilh\AppData\Local\Android\Sdk\platform-tools
2- ./adb tcpip 5555
3- ./adb connect 192.168.1.72:5555

Coisas a fazer pequenas
    -Controlar progressBall;
    -Resolver Bug:Ao tar na tourPage e clicar no botao inferior do telefone para voltar o audio ainda toca e nao quero.

Metas no Sistema
    -Selecionar posX e posY;    >---------FEITO----------<
    -NFC;     >---------FEITO----------<
    -Estatisticas da app no strapi;  >---------FEITO----------<
    -IA no backend e na aplicacao;    >---------FEITO----------<
    -BEACONS bluetooth;
