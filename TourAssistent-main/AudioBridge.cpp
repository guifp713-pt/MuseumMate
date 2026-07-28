#include "AudioBridge.h"
#include <QCoreApplication>
#include <QMetaObject>

#ifdef Q_OS_ANDROID             //Funciona em Android e Desktop pois os includes estao
#include <QGuiApplication>      //dentro do if e so rodam se o projeto for rodado en android
#include <QJniEnvironment>
#include <QJniObject>
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
