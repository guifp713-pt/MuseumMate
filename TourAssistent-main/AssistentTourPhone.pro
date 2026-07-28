
QT += core gui quick virtualkeyboard network multimedia

TARGET = AssistentTourPhone
TEMPLATE = app
CONFIG += c++17

# --- Configuração QZXing ---
# Ativa suporte para QML e o filtro de vídeo para câmara (Multimedia)
CONFIG += qzxing_qml qzxing_multimedia

# Adiciona a pasta qzxing ao caminho de busca do compilador
INCLUDEPATH += $$PWD/qzxing

# Inclui o ficheiro de configuração da biblioteca QR Code
include(qzxing/QZXing.pri)
# ---------------------------

SOURCES += \
    main.cpp \
    AndroidPermission.cpp \
    FileHelper.cpp \
    AudioBridge.cpp \
    nfcmanager.cpp

HEADERS += \
    AndroidPermission.h \
    FileHelper.h \
    AudioBridge.h \
    nfcmanager.h

RESOURCES += resources.qrc

# Configurações Android
ANDROID_PACKAGE_SOURCE_DIR = $$PWD/android
ANDROID_TARGET_SDK_VERSION = 34
ANDROID_MIN_SDK_VERSION = 23

DISTFILES += \
    android/AndroidManifest.xml \
    android/build.gradle \
    android/src/org/qtproject/example/MuseumActivity.java \
    android/src/org/qtproject/example/TourAudioService.java

# OpenSSL (Certifica-te que este caminho está correto no teu PC)
ANDROID_OPENSSL_PATH = "C:\Users\guilh\AppData\Local\Android\Sdk\android_openssl-master\ssl_3"

contains(ANDROID_TARGET_ARCH, arm64-v8a) {
    ANDROID_EXTRA_LIBS += \
        $$ANDROID_OPENSSL_PATH/arm64-v8a/libcrypto_3.so \
        $$ANDROID_OPENSSL_PATH/arm64-v8a/libssl_3.so
}