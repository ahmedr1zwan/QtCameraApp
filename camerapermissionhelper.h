#ifndef CAMERAPERMISSIONHELPER_H
#define CAMERAPERMISSIONHELPER_H

#include <QObject>
#include <QPermission>

QT_BEGIN_NAMESPACE
class QCameraPermission;
QT_END_NAMESPACE

class CameraPermissionHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasPermission READ hasPermission NOTIFY permissionChanged)

public:
    explicit CameraPermissionHelper(QObject *parent = nullptr);
    Q_INVOKABLE void requestPermission();
    bool hasPermission() const { return m_hasPermission; }

signals:
    void permissionChanged();

private:
    void checkPermission();
    bool m_hasPermission = false;
};

#endif // CAMERAPERMISSIONHELPER_H

