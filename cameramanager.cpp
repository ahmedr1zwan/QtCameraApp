#include "cameramanager.h"
#include <QMediaDevices>
#include <QCameraDevice>
#include <QDebug>

CameraManager::CameraManager(QObject *parent)
    : QAbstractListModel(parent)
{
    refreshCameras();
}

int CameraManager::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_cameras.size();
}

QVariant CameraManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_cameras.size())
        return QVariant();
    
    const CameraInfo &camera = m_cameras.at(index.row());
    
    switch (role) {
    case CameraIdRole:
        return camera.id;
    case DescriptionRole:
        return camera.description;
    case IsAvailableRole:
        return camera.isAvailable;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> CameraManager::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[CameraIdRole] = "cameraId";
    roles[DescriptionRole] = "description";
    roles[IsAvailableRole] = "isAvailable";
    return roles;
}

void CameraManager::refreshCameras()
{
    beginResetModel();
    m_cameras.clear();
    updateCameraList();
    endResetModel();
    emit camerasChanged();
}

void CameraManager::updateCameraList()
{
    QMediaDevices devices;
    const QList<QCameraDevice> availableCameras = devices.videoInputs();
    
    qDebug() << "Found" << availableCameras.size() << "camera(s)";
    
    for (const QCameraDevice &device : availableCameras) {
        QString id = QString::fromUtf8(device.id());
        QString description = device.description();
        bool isAvailable = !device.isNull();
        
        m_cameras.append(CameraInfo(id, description, isAvailable));
        qDebug() << "Camera:" << description << "ID:" << id;
    }
}

QString CameraManager::getCameraId(int index)
{
    if (index >= 0 && index < m_cameras.size())
        return m_cameras.at(index).id;
    return QString();
}

QString CameraManager::getCameraDescription(int index)
{
    if (index >= 0 && index < m_cameras.size())
        return m_cameras.at(index).description;
    return QString();
}

