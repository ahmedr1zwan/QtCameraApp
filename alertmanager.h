#ifndef ALERTMANAGER_H
#define ALERTMANAGER_H

#include <QObject>
#include <QAbstractListModel>
#include <QList>
#include <QDateTime>
#include <QString>

struct AlertEntry {
    QDateTime timestamp;
    QString cameraName;
    QString cameraId;
    QString alertType;  // "motion", "tripwire", "roi", etc.
    QString description;
    QString snapshotPath;  // Optional path to snapshot
    
    AlertEntry() {}
    AlertEntry(const QDateTime &ts, const QString &camName, const QString &camId,
               const QString &type, const QString &desc, const QString &snapshot = QString())
        : timestamp(ts), cameraName(camName), cameraId(camId),
          alertType(type), description(desc), snapshotPath(snapshot) {}
};

class AlertManager : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int alertCount READ alertCount NOTIFY alertsChanged)

public:
    enum Roles {
        TimestampRole = Qt::UserRole + 1,
        CameraNameRole,
        CameraIdRole,
        AlertTypeRole,
        DescriptionRole,
        SnapshotPathRole
    };

    explicit AlertManager(QObject *parent = nullptr);
    
    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    // Public API
    Q_INVOKABLE void addAlert(const QString &cameraName, const QString &cameraId,
                              const QString &alertType, const QString &description,
                              const QString &snapshotPath = QString());
    Q_INVOKABLE void clearAlerts();
    Q_INVOKABLE bool exportToCSV(const QString &filePath);
    Q_INVOKABLE bool exportToJSON(const QString &filePath);
    Q_INVOKABLE QString getDefaultExportPath() const;
    
    int alertCount() const { return m_alerts.size(); }

signals:
    void alertsChanged();
    void newAlert(const QString &cameraName, const QString &alertType);

private:
    QList<AlertEntry> m_alerts;
    static const int MAX_ALERTS = 1000;  // Limit to prevent memory issues
};

#endif // ALERTMANAGER_H

