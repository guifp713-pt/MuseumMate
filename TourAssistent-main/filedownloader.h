#ifndef FILEDOWNLOADER_H
#define FILEDOWNLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QFile>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>

#ifndef Q_MOC_RUN
// O MOC vai ignorar o que estiver aqui dentro se houver macros estranhas
#endif

class FileDownloader : public QObject {
    Q_OBJECT
public:
    explicit FileDownloader(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void downloadFile(QString url, QString fileName) {
        if (url.isEmpty()) return;

        if (url.startsWith("/")) {
            url = "http://10.90.175.27:1337" + url;
        }

        QNetworkRequest request((QUrl(url)));
        QNetworkReply *reply = m_manager.get(request);

        connect(reply, &QNetworkReply::finished, this, [this, reply, fileName]() {
            if (reply->error() == QNetworkReply::NoError) {
                QString folder = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
                QDir().mkpath(folder);
                QString fullPath = folder + "/" + fileName;
                QFile file(fullPath);
                if (file.open(QIODevice::WriteOnly)) {
                    file.write(reply->readAll());
                    file.close();
                    emit downloadFinished(fileName, fullPath, true);
                }
            } else {
                emit downloadFinished(fileName, "", false);
            }
            reply->deleteLater();
        });
    }

signals:
    void downloadFinished(QString fileName, QString localPath, bool success);

private:
    QNetworkAccessManager m_manager;
};

#endif
