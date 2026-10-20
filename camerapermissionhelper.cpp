#include "camerapermissionhelper.h"
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
#include <QPermissions>
#endif
#include <QGuiApplication>
#include <QDebug>

CameraPermissionHelper::CameraPermissionHelper(QObject *parent)
    : QObject(parent)
{
    checkPermission();
}

void CameraPermissionHelper::checkPermission()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    QGuiApplication *app = qobject_cast<QGuiApplication*>(QGuiApplication::instance());
    if (!app) {
        qDebug() << "QGuiApplication instance not available";
        return;
    }
    
    QCameraPermission cameraPermission;
    auto status = app->checkPermission(cameraPermission);
    
    const bool wasGranted = m_hasPermission;
    m_hasPermission = (status == Qt::PermissionStatus::Granted);
    
    if (wasGranted != m_hasPermission) {
        emit permissionChanged();
    }
    
    qDebug() << "Camera permission status:" << status;
    
    // If undetermined, automatically request
    if (status == Qt::PermissionStatus::Undetermined) {
        requestPermission();
    }
#else
    m_hasPermission = true;
    emit permissionChanged();
#endif
}

void CameraPermissionHelper::requestPermission()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    QGuiApplication *app = qobject_cast<QGuiApplication*>(QGuiApplication::instance());
    if (!app) {
        qDebug() << "QGuiApplication instance not available";
        return;
    }
    
    QCameraPermission cameraPermission;
    app->requestPermission(cameraPermission, [this](const QPermission &permission) {
        const bool wasGranted = m_hasPermission;
        m_hasPermission = (permission.status() == Qt::PermissionStatus::Granted);
        
        if (wasGranted != m_hasPermission) {
            emit permissionChanged();
        }
        
        qDebug() << "Camera permission request result:" << permission.status();
    });
#else
    if (!m_hasPermission) {
        m_hasPermission = true;
        emit permissionChanged();
    }
#endif
}
