#include "AndroidPermission.h"

#include <QGuiApplication>
#include <QPermissions>

AndroidPermission::AndroidPermission(QObject *parent)
    : QObject(parent)
{
}

bool AndroidPermission::checkCameraPermission()
{
#ifdef Q_OS_ANDROID

    auto status = qApp->checkPermission(QCameraPermission{});

    return status == Qt::PermissionStatus::Granted;

#else
    return true;
#endif
}

void AndroidPermission::requestCameraPermission()
{
#ifdef Q_OS_ANDROID

    qApp->requestPermission(
        QCameraPermission{},
        [](const QPermission &permission)
        {
            Q_UNUSED(permission);
        }
        );

#endif
}
