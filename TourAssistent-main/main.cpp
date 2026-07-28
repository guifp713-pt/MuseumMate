#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSslConfiguration>
#include <QSslSocket>
#include <QQmlContext>

// Includes locais do projeto
#include "AudioBridge.h"
#include "FileHelper.h"
#include "QZXing.h"
#include "AndroidPermission.h"
#include "nfcmanager.h" // ADICIONADO: Necessário para compilar a classe NfcManager abaixo

int main(int argc, char *argv[])
{
    // Melhora a renderização em alguns dispositivos Android
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");

    QGuiApplication app(argc, argv);

    NfcManager nfcManager;

    // Configuração SSL para evitar erros em downloads HTTPS no Android
    QSslConfiguration sslConfig = QSslConfiguration::defaultConfiguration();
    sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
    QSslConfiguration::setDefaultConfiguration(sslConfig);

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("NfcManager", &nfcManager);

    // 1. Registo do QZXing para leitura de QR Code
    QZXing::registerQMLTypes();
    QZXing::registerQMLImageProvider(engine);

    FileHelper fileHelper;
    engine.rootContext()->setContextProperty(
        "FileHelper",
        &fileHelper
        );

    AudioBridge audioBridge;
    engine.rootContext()->setContextProperty(
        "AudioBridge",
        &audioBridge
        );

    // 3. Instanciar e expor permissões Android ao QML
    AndroidPermission androidPermission;
    engine.rootContext()->setContextProperty(
        "AndroidPermission",
        &androidPermission
        );

    const QUrl url(QStringLiteral("qrc:/main.qml"));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
        );

    engine.load(url);

    return app.exec();
}