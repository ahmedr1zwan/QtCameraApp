#include "camerapermissionhelper.h"
#include <QPermissions>
#include <QGuiApplication>
#include <QDebug>

CameraPermissionHelper::CameraPermissionHelper(QObject *parent)
    : QObject(parent)
{
    checkPermission();
}

void CameraPermissionHelper::checkPermission()
{
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
}

void CameraPermissionHelper::requestPermission()
{
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
}

