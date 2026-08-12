import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtMultimedia
import QZXing
import "ApiHandler.js" as AH
import "AnalyticsHandler.js" as Analytics

ApplicationWindow  {
    id: root
    visible: true 
    width: 400
    height: 700
    title: "Museum Mate"
    onClosing: function(close) {
            if (gameLoader.active && gameLoader.item && typeof gameLoader.item.handleBack === "function") {
                if (gameLoader.item.handleBack()) {
                    close.accepted = false
                    return
                }
            }

            if (nextPage !== 0) {
                nextPage = 0
                close.accepted = false
            } else {
                close.accepted = true
            }
        }

    property var languages: ["Português", "English", "Español", "Français"]
    property var marcadoresLinguas: ["pt", "en", "es" , "fr"]
    property string linguaEscolhida: "pt"
    property string linguaGuardada: ""
    property int nextPage: 0
    property bool isLoading: false
    property string sessionId: ""
    property bool postData: false
    property bool isHomePageVisible: false
    property bool isTourPageVisible: false
    property string pendingNfcCode: ""
    property bool entityConfigError: false
    property bool offlineNoContentError: false
    property bool downloadingContent: false
    property string pendingSyncDocId: ""
    property string pendingSyncLang: ""
    property var pendingSyncCallback: null
    property var appData: ({
                               "entities": [],
                               "maps": [],
                               "areas": [],
                               "items": [],
                               "dictionary": {},
                               "tours": {},
                               "tourItem": {},
                               "tourSteps": {}
                           })

    // --- LÓGICA DE DADOS ---
    // Aplica os dados (já em cache, ou acabados de descarregar) ao appData —
    // sempre resolve URLs de media através da pasta local desta entidade/língua.
    function aplicarDados(dados, lingua, passarPagina) {
        var localPath = FileHelper.getLocalMediaFolder(AH.ACTIVE_ENTITY_DOCUMENT_ID, lingua)
        appData = {
            "entities": AH.getEntities(dados, localPath),
            "maps": AH.getMaps(dados, localPath),
            "areas": AH.getAreas(dados, localPath),
            "items": AH.getItems(dados, localPath),
            "dictionary": AH.getDictionary(dados, localPath),
            "tours": AH.getTours(dados, localPath),
            "tourItem": AH.getAllTourItems(dados, localPath),
            "tourSteps": AH.getAllTourSteps(dados, localPath)
        }
        if (passarPagina) {
            nextPage = 1
        }
    }

    function carregarDadosArranque(lingua) {
        AH.getCachedData(lingua, function(cachedDados) {
            if (cachedDados && cachedDados.length > 0) {
                aplicarDados(cachedDados, lingua, false)
                return
            }

            AH.fetchFromNetwork(lingua, function(dados, errorReason) {
                if (errorReason || !dados || dados.length === 0)
                    return
                if (nextPage !== 0 || downloadingContent || lingua !== linguaEscolhida)
                    return
                aplicarDados(dados, lingua, false)
            })
        })
    }

    function carregarDados(lingua, passarPagina) {
        isLoading = true
        entityConfigError = false
        offlineNoContentError = false

        AH.getCachedData(lingua, function(cachedDados) {
            if (cachedDados && cachedDados.length > 0) {
                aplicarDados(cachedDados, lingua, passarPagina)
                isLoading = false
                return
            }

            downloadingContent = true
            AH.fetchFromNetwork(lingua, function(dados, errorReason) {
                if (errorReason === "offline") {
                    console.error("Sem cache local e sem rede — impossível carregar conteúdo.")
                    downloadingContent = false
                    isLoading = false
                    offlineNoContentError = true
                    return
                }

                if (!dados || dados.length === 0) {
                    console.error("Entidade ativa (documentId) não encontrada — a mostrar erro de configuração.")
                    downloadingContent = false
                    isLoading = false
                    entityConfigError = true
                    return
                }

                var mediaRaw = AH.extractMediaUrls(dados)
                var media = [...new Set(mediaRaw)]

                var finalizar = function() {
                    AH.saveToCache(lingua, dados)
                    downloadingContent = false
                    isLoading = false
                    aplicarDados(dados, lingua, passarPagina)
                }

                if (media.length === 0) {
                    finalizar()
                    return
                }

                pendingSyncDocId = AH.ACTIVE_ENTITY_DOCUMENT_ID
                pendingSyncLang = lingua
                pendingSyncCallback = finalizar
                FileHelper.downloadFiles(media, AH.baseUrl, AH.ACTIVE_ENTITY_DOCUMENT_ID, lingua)
            })
        })
    }

    Connections {
        target: FileHelper
        function onMediaSyncFinished(documentId, lang) {
            if (documentId === pendingSyncDocId && lang === pendingSyncLang && pendingSyncCallback) {
                var callback = pendingSyncCallback
                pendingSyncCallback = null
                callback()
            }
        }
    }

    Component.onCompleted: {
        root.sessionId = "SESS_" + Math.random().toString(36).substring(2, 11).toUpperCase() + Date.now().toString(36).toUpperCase()
        console.log("Nova sessão iniciada:", root.sessionId)

        AH.setFileExistsChecker(FileHelper.localFileExists)
        carregarDadosArranque(linguaEscolhida)
        Analytics.syncCache()
    }

        Connections {
            target: typeof NfcManager !== "undefined" ? NfcManager : null

            function onTagDetected(tagCode) {
                var cleanTag = String(tagCode).trim();

                // A HomePage e a TourPage têm cada uma a sua própria Connections
                // e tratam a tag diretamente enquanto estiverem visíveis. Se
                // interviéssemos aqui também, pisávamos o pendingNfcCode delas
                // (ele fica preso por nunca ser consumido) e podíamos acabar a
                // reprocessar uma tag antiga da próxima vez que essa página for
                // recriada. Por isso só atuamos quando estamos fora de ambas.
                if (isHomePageVisible || isTourPageVisible) {
                    console.log("NFC MAIN: HomePage/TourPage já tratam a tag diretamente:", cleanTag);
                    return;
                }

                console.log("NFC MAIN: Fora da HomePage/TourPage — a redirecionar. Código pendente:", cleanTag);

                pendingNfcCode = cleanTag;
                if (nextPage !== 1) {
                    nextPage = 1;
                }

                Qt.callLater(function() {
                    gameLoader.item.nextPageWelcome = 1;
                });
            }
        }

    QtObject {
        id: audioManager
        property string currentItemName: ""
        property string currentItemImage: ""
        property string currentSource: ""
        property int contadorParagens: 1
        property int valorEstaticoStop: 0
        property var tourInfo: null
        property var tourInfoItem: []
        readonly property var player: playerGlobal

        function playCurrentAudio() {
            let item = tourInfoItem[contadorParagens - 1]
            if (!item)
                return
            currentSource = item.audioItem
            currentItemName = item.nameItem
            currentItemImage = item.coverUrlItem

            playerGlobal.stop()
            playerGlobal.source = currentSource
            playerGlobal.play()
        }

        function pause() {
            playerGlobal.pause()
        }

        function next() {
            if (contadorParagens < valorEstaticoStop) {
                contadorParagens++
                playCurrentAudio()
            }
        }

        function prev() {
            if (contadorParagens > 1) {
                contadorParagens--
                playCurrentAudio()
            }
        }
    }

    // Rectangle {
    //     id: recBorda
    //     anchors.fill: parent
    //     border.width: 3
    //     border.color: "black"
    //     color: "transparent"
    //     z: 9999
    // }


    // --- INTERFACE ---
    Column {
        id: col
        spacing: 10
        visible: nextPage === 0 && !entityConfigError && !offlineNoContentError && !downloadingContent
        anchors.centerIn: parent
        opacity: isLoading ? 0.5 : 1
        enabled: !isLoading

        Rectangle {
            id: recimgIconMuseum
            width: 60
            height: 60
            radius: 50
            border.width: 0.5
            border.color: "#E8E8E8"
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                width: 80
                height: 50
                source: "qrc:/images/images/IconMuseum.png"
                anchors.centerIn: parent
            }
        }

        Column {
            spacing: 15
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: appData.dictionary["mainName"] ? appData.dictionary["mainName"] : ""
                font.pixelSize: 36
                font.family: playfairSemiBold.name
                font.letterSpacing: 7.2
                font.capitalization: Font.AllUppercase
                color: "#000000"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: appData.entities.length > 0 ? appData.entities[0].nameEntity : ""
                font.pixelSize: 10
                font.family: interRegular.name
                font.letterSpacing: 4.8
                font.capitalization: Font.AllUppercase
                color: "#6b7280"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Rectangle {
            width: 60
            height: 2
            color: "#D4AF37"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: appData.dictionary["mainSelectLanguange"] ? appData.dictionary["mainSelectLanguange"] : ""
            font.pixelSize: 13
            font.family: interMedium.name
            font.letterSpacing: 3.8
            font.capitalization: Font.AllUppercase
            color: "#6b7280"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Repeater {
            model: marcadoresLinguas.length
            delegate: Rectangle {
                width: root.width - 80
                height: 60
                radius: 10
                border.color: mouseHandler.containsMouse ? "#D4AF37" : "#E8E8E8"
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    spacing: 20

                    Text {
                        text: marcadoresLinguas[index]
                        font.pixelSize: 15
                        color: mouseHandler.containsMouse ? "#D4AF37" : "#6b7280"
                    }

                    Text {
                        text: languages[index]
                        font.pixelSize: 15
                        color: mouseHandler.containsMouse ? "#D4AF37" : "#6b7280"
                    }
                }

                MouseArea {
                    id: mouseHandler
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        linguaEscolhida = marcadoresLinguas[index]
                        carregarDados(linguaEscolhida, true)

                        if(linguaEscolhida === linguaGuardada) {
                            postData = true
                            console.log("Lingua Igual")
                        } else {
                            linguaGuardada = linguaEscolhida
                            postData = false
                            console.log("Lingua Diferente a enviar dados...")
                        }

                        if(postData != true) {
                            Analytics.sendEvent("visit_start", root.linguaEscolhida, null, null, root.sessionId, true)
                            postData = true
                            console.log("Dados Enviados e alterados")
                        }
                    }
                }
            }
        }
    }

    // --- NAVEGAÇÃO (LOADER) ---
    Loader {
        id: gameLoader
        anchors.fill: parent
        active: nextPage !== 0
        opacity: active ? 1 : 0

        // Injetamos o objeto appData completo no WelcomePage
        sourceComponent: {
            if (nextPage === 1) return welcomePage
            return null
        }

        Behavior on opacity { NumberAnimation { duration: 500 } }
    }

    // --- ERRO DE CONFIGURAÇÃO (ecrã bloqueante) ---
    // Mostrado quando o documentId da entidade ativa (ApiHandler.js) não
    // corresponde a nenhuma entidade no Strapi. Cobre toda a janela e impede
    // qualquer navegação, em vez de deixar a app com ecrãs vazios.
    Rectangle {
        id: entityErrorScreen
        anchors.fill: parent
        z: 1000
        color: "#111827"
        visible: entityConfigError

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width - 80

            Text {
                text: "⚠️"
                font.pixelSize: 40
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Não foi possível carregar o museu"
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "A configuração ativa não corresponde a nenhum museu existente. Contacte o operador da aplicação."
                font.pixelSize: 13
                color: "#d1d5db"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // --- SEM CONTEÚDO OFFLINE (ecrã bloqueante) ---
    // Mostrado quando não há rede E não há nenhuma cache local para a
    // entidade/língua ativas (ex.: primeira abertura sem internet, ou troca de
    // museu antes de qualquer sincronização online neste dispositivo).
    Rectangle {
        id: offlineErrorScreen
        anchors.fill: parent
        z: 1000
        color: "#111827"
        visible: offlineNoContentError

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width - 80

            Text {
                text: "📡"
                font.pixelSize: 40
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Sem conteúdo disponível offline"
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Ligue-se à internet pelo menos uma vez para descarregar o conteúdo deste museu. Depois disso, a aplicação passa a funcionar sem ligação."
                font.pixelSize: 13
                color: "#d1d5db"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 140
                height: 40
                radius: 8
                color: "#374151"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "Tentar novamente"
                    color: "#ffffff"
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    // Este ecrã só pode surgir depois de o visitante escolher a
                    // língua, por isso o retry retoma essa escolha (avança para
                    // a app se o conteúdo for descarregado com sucesso).
                    onClicked: carregarDados(linguaEscolhida, true)
                }
            }
        }
    }

    // --- A DESCARREGAR CONTEÚDO (ecrã bloqueante) ---
    // Mostrado apenas na primeira vez que esta língua/entidade é usada neste
    // dispositivo (sem cache ainda). Bloqueia a navegação até o JSON e todos
    // os ficheiros de media terminarem de descarregar, para nunca deixar o
    // visitante entrar na app com conteúdo a meio do download.
    Rectangle {
        id: downloadingScreen
        anchors.fill: parent
        z: 1000
        color: "#111827"
        visible: downloadingContent

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width - 80

            BusyIndicator {
                running: downloadingContent
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "A descarregar conteúdo do museu…"
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Só é preciso uma vez por idioma — depois disto a aplicação funciona sem internet."
                font.pixelSize: 13
                color: "#d1d5db"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Component {
        id: welcomePage
        WelcomePage {
            appDataWelcome: root.appData
            linguaEscolhidaWelcome: root.linguaEscolhida
            onBack: nextPage = 0
        }
    }

    // --- FONTES ---
    FontLoader { id: playfairSemiBold; source: "qrc:/fonts/PlayfairDisplay-SemiBold.ttf" }
    FontLoader { id: interRegular; source: "qrc:/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interMedium; source: "qrc:/fonts/Inter_18pt-Medium.ttf" }

    MediaPlayer {
        id: playerGlobal
        audioOutput: AudioOutput {
            volume: 1.0
        }

        onMediaStatusChanged: {

            if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (audioManager.contadorParagens < audioManager.valorEstaticoStop) {
                    audioManager.contadorParagens++
                    audioManager.playCurrentAudio()
                } else {
                    stop()
                }
            }
        }
    }
}

/*                PC
*
*
* #include "AudioBridge.h"
#include <QCoreApplication>
#include <QMetaObject>

// --- CORREÇÃO AQUI ---
// Movemos os includes específicos de Android para dentro da proteção da plataforma.
// O compilador Desktop (Windows/MinGW) irá ignorar isto e o erro desaparece.
#ifdef Q_OS_ANDROID
#include <QGuiApplication>
#include <QJniEnvironment> // Antes estava fora
#include <QJniObject>      // Antes estava fora
#endif
// ----------------------

AudioBridge *AudioBridge::s_instance = nullptr;

AudioBridge::AudioBridge(QObject *parent)
  : QObject(parent)
{
  s_instance = this;
}

AudioBridge::~AudioBridge()
{
  if (s_instance == this) {
      s_instance = nullptr;
  }
}

AudioBridge *AudioBridge::instance()
{
  return s_instance;
}

void AudioBridge::setPlaylist(const QStringList &playlist, int currentIndex)
{
  m_playlist = playlist;
  m_currentIndex = currentIndex;

#ifdef Q_OS_ANDROID
  QJniEnvironment env;

  jclass stringClass = env->FindClass("java/lang/String");
  if (!stringClass) {
      return;
  }

  jobjectArray javaArray = env->NewObjectArray(playlist.size(), stringClass, nullptr);
  if (!javaArray) {
      env->DeleteLocalRef(stringClass);
      return;
  }

  for (int i = 0; i < playlist.size(); ++i) {
      QJniObject javaString = QJniObject::fromString(playlist.at(i));
      env->SetObjectArrayElement(javaArray, i, javaString.object());
  }

  QJniObject context = QNativeInterface::QAndroidApplication::context();

  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "setServicePlaylist",
      "(Landroid/content/Context;[Ljava/lang/String;I)V",
      context.object(),
      javaArray,
      currentIndex
      );

  env->DeleteLocalRef(javaArray);
  env->DeleteLocalRef(stringClass);
#endif
}

void AudioBridge::startAudio(QString url)
{
#ifdef Q_OS_ANDROID
  QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject jUrl = QJniObject::fromString(url);

  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "startService",
      "(Landroid/content/Context;Ljava/lang/String;)V",
      context,
      jUrl
      );
#else
  // Fallback silencioso para Desktop
  Q_UNUSED(url);
#endif
}

void AudioBridge::stopAudio()
{
#ifdef Q_OS_ANDROID
  if (QCoreApplication::closingDown()) {
      return;
  }

  QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "stopService",
      "(Landroid/content/Context;)V",
      context
      );
#endif
}

void AudioBridge::goToNext()
{
  if (m_currentIndex < m_playlist.size() - 1) {
      m_currentIndex++;
      QString url = m_playlist[m_currentIndex];
      startAudio(url);
      emit currentTrackChanged(m_currentIndex, url);
  }
}

void AudioBridge::goToPrevious()
{
  if (m_currentIndex > 0) {
      m_currentIndex--;
      QString url = m_playlist[m_currentIndex];
      startAudio(url);
      emit currentTrackChanged(m_currentIndex, url);
  }
}

void AudioBridge::pauseAudio()
{
#ifdef Q_OS_ANDROID
  QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "pauseAudio",
      "(Landroid/content/Context;)V",
      context.object()
      );
#endif
}

void AudioBridge::resumeAudio()
{
#ifdef Q_OS_ANDROID
  QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "resumeAudio",
      "(Landroid/content/Context;)V",
      context.object()
      );
#endif
}

void AudioBridge::handleTrackChangedFromJava(int index, const QString &url)
{
  m_currentIndex = index;
  emit currentTrackChanged(index, url);
}

void AudioBridge::seekTo(int msec)
{
#ifdef Q_OS_ANDROID
  QJniObject::callStaticMethod<void>(
      "org/qtproject/example/TourAudioService",
      "seekToPosition",
      "(I)V",
      msec
      );
#else
  // Fallback silencioso para Desktop
  Q_UNUSED(msec);
#endif
}

void AudioBridge::handlePositionChangedFromJava(int position, int duration)
{
  emit audioPositionChanged(position, duration);
}

#ifdef Q_OS_ANDROID
extern "C" JNIEXPORT void JNICALL
Java_org_qtproject_example_TourAudioService_nativeTrackChanged(
  JNIEnv *env, jobject thiz, jint index, jstring url)
{
  Q_UNUSED(thiz);
  if (!url) return;

  const char *nativeString = env->GetStringUTFChars(url, nullptr);
  QString qurl = QString::fromUtf8(nativeString);
  env->ReleaseStringUTFChars(url, nativeString);

  AudioBridge *bridge = AudioBridge::instance();
  if (bridge) {
      QMetaObject::invokeMethod(bridge, [bridge, index, qurl]() {
          bridge->handleTrackChangedFromJava(index, qurl);
      }, Qt::QueuedConnection);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_org_qtproject_example_TourAudioService_nativePositionChanged(
  JNIEnv *env, jobject thiz, jint position, jint duration)
{
  Q_UNUSED(env);
  Q_UNUSED(thiz);

  AudioBridge *bridge = AudioBridge::instance();
  if (bridge) {
      QMetaObject::invokeMethod(bridge, [bridge, position, duration]() {
          bridge->handlePositionChangedFromJava(position, duration);
      }, Qt::QueuedConnection);
  }
}
#endif
