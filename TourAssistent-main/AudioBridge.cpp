#include "AudioBridge.h"
#include <QCoreApplication>
#include <QMetaObject>

#ifdef Q_OS_ANDROID             //Funciona em Android e Desktop pois os includes estao
#include <QGuiApplication>      //dentro do if e so rodam se o projeto for rodado en android
#include <QJniEnvironment>
#include <QJniObject>
#else
#include <QAudioOutput>
#include <QDebug>
#include <QMediaPlayer>
#include <QUrl>
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

#ifndef Q_OS_ANDROID
void AudioBridge::ensureDesktopPlayer()
{
    if (m_player) {
        return;
    }

    m_player = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_player->setAudioOutput(m_audioOutput);

    connect(m_player, &QMediaPlayer::positionChanged, this, [this](qint64 position) {
        emit audioPositionChanged(int(position), int(m_player->duration()));
    });
    connect(m_player, &QMediaPlayer::durationChanged, this, [this](qint64 duration) {
        emit audioPositionChanged(int(m_player->position()), int(duration));
    });
    // Equivalente ao OnCompletionListener do TourAudioService: avança para o
    // passo seguinte e, no fim da playlist, deixa de mostrar "a tocar".
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status) {
        if (status != QMediaPlayer::EndOfMedia) {
            return;
        }
        if (m_currentIndex < m_playlist.size() - 1) {
            goToNext();
        } else {
            emit currentTrackChanged(m_currentIndex, QString());
        }
    });
    connect(m_player, &QMediaPlayer::errorOccurred, this,
            [](QMediaPlayer::Error, const QString &errorString) {
        qWarning() << "AudioBridge (desktop): erro de reproducao:" << errorString;
    });
}
#endif

AudioBridge *AudioBridge::instance()
{
    return s_instance;
}

void AudioBridge::setPlaylist(const QStringList &playlist, int currentIndex,
                               const QStringList &titles, const QStringList &covers,
                               const QString &tourName)
{
    m_playlist = playlist;
    m_currentIndex = currentIndex;

#ifdef Q_OS_ANDROID
    QJniEnvironment env;

    jclass stringClass = env->FindClass("java/lang/String");
    if (!stringClass) {
        return;
    }

    auto toJavaStringArray = [&env, stringClass](const QStringList &list) -> jobjectArray {
        jobjectArray array = env->NewObjectArray(list.size(), stringClass, nullptr);
        if (!array) {
            return nullptr;
        }
        for (int i = 0; i < list.size(); ++i) {
            QJniObject javaString = QJniObject::fromString(list.at(i));
            env->SetObjectArrayElement(array, i, javaString.object());
        }
        return array;
    };

    jobjectArray urlsArray = toJavaStringArray(playlist);
    jobjectArray titlesArray = toJavaStringArray(titles);
    jobjectArray coversArray = toJavaStringArray(covers);

    if (!urlsArray || !titlesArray || !coversArray) {
        if (urlsArray) env->DeleteLocalRef(urlsArray);
        if (titlesArray) env->DeleteLocalRef(titlesArray);
        if (coversArray) env->DeleteLocalRef(coversArray);
        env->DeleteLocalRef(stringClass);
        return;
    }

    QJniObject context = QNativeInterface::QAndroidApplication::context();
    QJniObject jTourName = QJniObject::fromString(tourName);

    QJniObject::callStaticMethod<void>(
        "org/qtproject/example/TourAudioService",
        "setServicePlaylist",
        "(Landroid/content/Context;[Ljava/lang/String;[Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;I)V",
        context.object(),
        urlsArray,
        titlesArray,
        coversArray,
        jTourName.object(),
        currentIndex
        );

    env->DeleteLocalRef(urlsArray);
    env->DeleteLocalRef(titlesArray);
    env->DeleteLocalRef(coversArray);
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
    ensureDesktopPlayer();
    m_player->stop();
    if (url.isEmpty()) {
        // Passo sem áudio: fica em silêncio
        m_player->setSource(QUrl());
        return;
    }
    // URLs (http/file/qrc) mantêm-se; caminhos simples viram file://
    const QUrl source = url.contains(QStringLiteral("://")) ? QUrl(url) : QUrl::fromLocalFile(url);
    m_player->setSource(source);
    m_player->play();
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
#else
    if (m_player) {
        m_player->stop();
    }
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
#else
    if (m_player) {
        m_player->pause();
    }
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
#else
    if (m_player) {
        m_player->play();
    }
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
    if (m_player) {
        m_player->setPosition(msec);
    }
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
