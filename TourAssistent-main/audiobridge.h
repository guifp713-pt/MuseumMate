#ifndef AUDIOBRIDGE_H
#define AUDIOBRIDGE_H

#include <QObject>
#include <QStringList>

#ifndef Q_OS_ANDROID
class QMediaPlayer;
class QAudioOutput;
#endif

class AudioBridge : public QObject
{
    Q_OBJECT
public:
    explicit AudioBridge(QObject *parent = nullptr);

    // CORREÇÃO: Declarar o destrutor aqui para que o .cpp o possa implementar
    ~AudioBridge();

    static AudioBridge *instance();

    Q_INVOKABLE void startAudio(QString url);
    Q_INVOKABLE void stopAudio();
    Q_INVOKABLE void pauseAudio();
    Q_INVOKABLE void resumeAudio();
    Q_INVOKABLE void setPlaylist(const QStringList &playlist, int currentIndex,
                                  const QStringList &titles = QStringList(),
                                  const QStringList &covers = QStringList(),
                                  const QString &tourName = QString());
    Q_INVOKABLE void goToNext();
    Q_INVOKABLE void goToPrevious();
    Q_INVOKABLE void seekTo(int msec);

    void handleTrackChangedFromJava(int index, const QString &url);

    // NOVO: Recebe o progresso enviado pelo loop do Java
    void handlePositionChangedFromJava(int position, int duration);

signals:
    void currentTrackChanged(int index, const QString &url);

    // NOVO: Sinal capturado pelo teu ficheiro QML
    void audioPositionChanged(int position, int duration);

private:
    static AudioBridge *s_instance;
    QStringList m_playlist;
    int m_currentIndex = 0;

#ifndef Q_OS_ANDROID
    // Reprodutor de Desktop (no Android o áudio corre no TourAudioService)
    void ensureDesktopPlayer();
    QMediaPlayer *m_player = nullptr;
    QAudioOutput *m_audioOutput = nullptr;
#endif
};

#endif // AUDIOBRIDGE_H