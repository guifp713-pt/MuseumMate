#include "FileHelper.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QUrl>
#include <QSharedPointer>

FileHelper::FileHelper(QObject *parent) : QObject(parent) {}

void FileHelper::downloadFiles(QStringList urls, QString baseUrl, QString documentId, QString lang)
{
    QString basePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/media/" + documentId + "/" + lang;

    if (!QDir().mkpath(basePath)) {
        qDebug() << "Erro ao criar pasta:" << basePath;
    }

    // Só os ficheiros que ainda não existem em disco contam para saber quando
    // o download termina — os já existentes não geram pedido de rede.
    QStringList pending;
    for (const QString &url : urls) {
        if (url.isEmpty()) continue;
        QString fileName = url.split("/").last();
        if (QFile::exists(basePath + "/" + fileName)) {
            qDebug() << "Já existe:" << (basePath + "/" + fileName);
            continue;
        }
        pending.append(url);
    }

    if (pending.isEmpty()) {
        emit mediaSyncFinished(documentId, lang);
        return;
    }

    QNetworkAccessManager *manager = new QNetworkAccessManager(this);
    QSharedPointer<int> remaining(new int(pending.size()));

    for (const QString &url : pending) {
        QString fullUrl = baseUrl + url;
        QString fileName = url.split("/").last();
        QString filePath = basePath + "/" + fileName;

        QNetworkRequest request((QUrl(fullUrl)));
        QNetworkReply *reply = manager->get(request);

        connect(reply, &QNetworkReply::finished, [this, reply, filePath, documentId, lang, remaining]() {
            if (reply->error() == QNetworkReply::NoError) {
                QFile file(filePath);
                if (file.open(QIODevice::WriteOnly)) {
                    file.write(reply->readAll());
                    file.close();
                    qDebug() << "Guardado com sucesso:" << filePath;
                }
            } else {
                qDebug() << "Erro no download de" << filePath << ":" << reply->errorString();
            }
            reply->deleteLater();

            (*remaining)--;
            if (*remaining <= 0) {
                emit mediaSyncFinished(documentId, lang);
            }
        });
    }
}

QString FileHelper::getLocalMediaFolder(QString documentId, QString lang)
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/media/" + documentId + "/" + lang;
    return QUrl::fromLocalFile(path).toString() + "/";
}

bool FileHelper::localFileExists(QString localFileUrl)
{
    QUrl url(localFileUrl);
    QString path = url.isLocalFile() ? url.toLocalFile() : localFileUrl;
    return QFile::exists(path);
}
