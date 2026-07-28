#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>
#include <QStringList>

class FileHelper : public QObject
{
    Q_OBJECT

public:
    explicit FileHelper(QObject *parent = nullptr);

    // Q_INVOKABLE permite que estas funções sejam chamadas a partir do JS no QML
    // documentId identifica a entidade/museu ativo (ApiHandler.js ACTIVE_ENTITY_DOCUMENT_ID),
    // para que media de entidades diferentes nunca partilhe a mesma pasta local.
    Q_INVOKABLE void downloadFiles(QStringList urls, QString baseUrl, QString documentId, QString lang);
    Q_INVOKABLE QString getLocalMediaFolder(QString documentId, QString lang);
    // Confirma se um ficheiro local (caminho já resolvido, incl. file:// URI) existe de facto
    // em disco — usado por resolveUrl() para nunca apontar para um ficheiro cujo download
    // ainda não terminou (downloadFiles é assíncrono e não notifica conclusão ao QML).
    Q_INVOKABLE bool localFileExists(QString localFileUrl);

signals:
    // Emitido quando todos os ficheiros pedidos numa chamada a downloadFiles() para
    // este (documentId, lang) terminaram (com sucesso ou erro) — permite ao QML
    // esperar pelo fim real do download antes de considerar o conteúdo disponível
    // offline, em vez de assumir que terminou por o pedido ter sido feito.
    void mediaSyncFinished(QString documentId, QString lang);
};

#endif // FILEHELPER_H
