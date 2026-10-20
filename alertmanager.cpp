#include "alertmanager.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

namespace {
QString csvField(QString value)
{
    value.replace('"', QStringLiteral("\"\""));
    return QStringLiteral("\"") + value + QStringLiteral("\"");
}
}

AlertManager::AlertManager(QObject *parent)
    : QAbstractListModel(parent)
{
}

int AlertManager::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_alerts.size();
}

QVariant AlertManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_alerts.size())
        return QVariant();
    
    const AlertEntry &alert = m_alerts.at(index.row());
    
    switch (role) {
    case TimestampRole:
        return alert.timestamp.toString(Qt::ISODate);
    case CameraNameRole:
        return alert.cameraName;
    case CameraIdRole:
        return alert.cameraId;
    case AlertTypeRole:
        return alert.alertType;
    case DescriptionRole:
        return alert.description;
    case SnapshotPathRole:
        return alert.snapshotPath;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AlertManager::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TimestampRole] = "timestamp";
    roles[CameraNameRole] = "cameraName";
    roles[CameraIdRole] = "cameraId";
    roles[AlertTypeRole] = "alertType";
    roles[DescriptionRole] = "description";
    roles[SnapshotPathRole] = "snapshotPath";
    return roles;
}

void AlertManager::addAlert(const QString &cameraName, const QString &cameraId,
                            const QString &alertType, const QString &description,
                            const QString &snapshotPath)
{
    beginInsertRows(QModelIndex(), 0, 0);
    
    AlertEntry alert(QDateTime::currentDateTime(), cameraName, cameraId,
                     alertType, description, snapshotPath);
    m_alerts.prepend(alert);  // Add to beginning (newest first)
    
    endInsertRows();

    if (m_alerts.size() > MAX_ALERTS) {
        beginRemoveRows(QModelIndex(), MAX_ALERTS, m_alerts.size() - 1);
        m_alerts.remove(MAX_ALERTS, m_alerts.size() - MAX_ALERTS);
        endRemoveRows();
    }
    
    emit alertsChanged();
    emit newAlert(cameraName, alertType);
    
    qDebug() << "Alert added:" << alertType << "from" << cameraName;
}

void AlertManager::clearAlerts()
{
    beginResetModel();
    m_alerts.clear();
    endResetModel();
    emit alertsChanged();
}

bool AlertManager::exportToCSV(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "Failed to open file for CSV export:" << filePath;
        return false;
    }
    
    QTextStream out(&file);
    
    // Write header
    out << "Timestamp,Camera Name,Camera ID,Alert Type,Description,Snapshot Path\n";
    
    // Write data
    for (const AlertEntry &alert : m_alerts) {
        out << csvField(alert.timestamp.toString(Qt::ISODateWithMs)) << ","
            << csvField(alert.cameraName) << ","
            << csvField(alert.cameraId) << ","
            << csvField(alert.alertType) << ","
            << csvField(alert.description) << ","
            << csvField(alert.snapshotPath) << "\n";
    }
    
    file.close();
    qDebug() << "Exported" << m_alerts.size() << "alerts to CSV:" << filePath;
    return true;
}

bool AlertManager::exportToJSON(const QString &filePath)
{
    QJsonArray alertsArray;
    
    for (const AlertEntry &alert : m_alerts) {
        QJsonObject alertObj;
        alertObj["timestamp"] = alert.timestamp.toString(Qt::ISODate);
        alertObj["cameraName"] = alert.cameraName;
        alertObj["cameraId"] = alert.cameraId;
        alertObj["alertType"] = alert.alertType;
        alertObj["description"] = alert.description;
        alertObj["snapshotPath"] = alert.snapshotPath;
        alertsArray.append(alertObj);
    }
    
    QJsonObject rootObj;
    rootObj["alerts"] = alertsArray;
    rootObj["exportDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    rootObj["totalAlerts"] = m_alerts.size();
    
    QJsonDocument doc(rootObj);
    
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "Failed to open file for JSON export:" << filePath;
        return false;
    }
    
    file.write(doc.toJson());
    file.close();
    qDebug() << "Exported" << m_alerts.size() << "alerts to JSON:" << filePath;
    return true;
}

QString AlertManager::getDefaultExportPath() const
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString exportDir = documentsPath + "/QtCameraApp/Exports";
    
    QDir dir;
    if (!dir.exists(exportDir)) {
        dir.mkpath(exportDir);
    }
    
    return exportDir;
}
