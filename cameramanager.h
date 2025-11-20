#ifndef CAMERAMANAGER_H
#define CAMERAMANAGER_H

#include <QObject>
#include <QAbstractListModel>
#include <QList>
#include <QString>

QT_BEGIN_NAMESPACE
class QCameraDevice;
QT_END_NAMESPACE

struct CameraInfo {
    QString id;
    QString description;
    bool isAvailable;
    
    CameraInfo() : isAvailable(false) {}
    CameraInfo(const QString &id, const QString &desc, bool available)
        : id(id), description(desc), isAvailable(available) {}
};

class CameraManager : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int availableCameraCount READ availableCameraCount NOTIFY camerasChanged)

public:
    enum Roles {
        CameraIdRole = Qt::UserRole + 1,
        DescriptionRole,
        IsAvailableRole
    };

    explicit CameraManager(QObject *parent = nullptr);
    
    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    // Public API
    Q_INVOKABLE void refreshCameras();
    Q_INVOKABLE QString getCameraId(int index);
    Q_INVOKABLE QString getCameraDescription(int index);
    int availableCameraCount() const { return m_cameras.size(); }

signals:
    void camerasChanged();

private:
    QList<CameraInfo> m_cameras;
    void updateCameraList();
};

#endif // CAMERAMANAGER_H

