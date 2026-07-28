#ifndef ANDROIDPERMISSION_H
#define ANDROIDPERMISSION_H

#include <QObject>

class AndroidPermission : public QObject
{
    Q_OBJECT

public:
    explicit AndroidPermission(QObject *parent = nullptr);

    Q_INVOKABLE bool checkCameraPermission();
    Q_INVOKABLE void requestCameraPermission();
};

#endif // ANDROIDPERMISSION_H
