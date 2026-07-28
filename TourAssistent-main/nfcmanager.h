#ifndef NFCMANAGER_H
#define NFCMANAGER_H

#include <QObject>
#include <QString>
#include <QDebug>

class NfcManager : public QObject
{
    Q_OBJECT
public:
    explicit NfcManager(QObject *parent = nullptr) : QObject(parent) {
        // Guarda a instância estática para o C++ conseguir aceder quando o Java chamar
        m_instance = this;
        qDebug() << "NfcManager CRIADO. Endereço:" << this;
    }

    static NfcManager* instance() { return m_instance; }

    // Função auxiliar chamada pelo C++ JNI para desencadear o signal para o QML
    void triggerTagDetected(const QString &code) {
        qDebug() << "NFC: Tag enviada pelo Java -> C++ -> QML. ID:" << code;
        emit tagDetected(code);
    }

signals:
    // O sinal que o QML vai escutar através do Connections
    void tagDetected(QString code);

private:
    // Obrigatório C++17 ativado no .pro (CONFIG += c++17)
    inline static NfcManager* m_instance = nullptr;
};

#endif // NFCMANAGER_H