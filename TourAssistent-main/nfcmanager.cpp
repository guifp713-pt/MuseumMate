#include "nfcmanager.h"
#include <QMetaObject>

#ifdef Q_OS_ANDROID
#include <jni.h>

extern "C" {
JNIEXPORT void JNICALL Java_org_qtproject_example_MuseumActivity_nativeNfcTagRead(JNIEnv *env, jobject obj, jstring code) {

    // 1. Proteção contra ponteiros nulos vindo do Java
    if (!code) {
        qWarning() << "NFC JNI: O documentId recebido do Java é nulo. Abortado.";
        return;
    }

    // 2. Extração segura da String
    const char *docIdChars = env->GetStringUTFChars(code, nullptr);
    QString docId = QString::fromUtf8(docIdChars);
    env->ReleaseStringUTFChars(code, docIdChars);

    // 3. Ponte segura para a Main Thread do Qt
    if (NfcManager::instance()) {
        QMetaObject::invokeMethod(NfcManager::instance(), [docId]() {
        NfcManager::instance()->triggerTagDetected(docId);
        }, Qt::QueuedConnection);
    } else {
        qWarning() << "NFC JNI: Instância de NfcManager não encontrada!";
            }
        }
    }
#endif