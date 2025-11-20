#include "snapshothelper.h"
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QDebug>

SnapshotHelper::SnapshotHelper(QObject *parent)
    : QObject(parent)
{
}

QString SnapshotHelper::getSnapshotsDirectory() const
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString snapshotsDir = documentsPath + "/QtCameraApp/Snapshots";
    
    QDir dir;
    if (!dir.exists(snapshotsDir)) {
        dir.mkpath(snapshotsDir);
    }
    
    return snapshotsDir;
}

QString SnapshotHelper::generateSnapshotFilename(const QString &cameraName) const
{
    QString dir = getSnapshotsDirectory();
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_hh-mm-ss");
    QString sanitizedName = cameraName;
    sanitizedName.replace(" ", "_");
    sanitizedName.replace("/", "_");
    sanitizedName.replace("\\", "_");
    
    return dir + "/" + sanitizedName + "_" + timestamp + ".jpg";
}

