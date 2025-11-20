#ifndef SNAPSHOTHELPER_H
#define SNAPSHOTHELPER_H

#include <QObject>
#include <QString>

class SnapshotHelper : public QObject
{
    Q_OBJECT

public:
    explicit SnapshotHelper(QObject *parent = nullptr);
    
    Q_INVOKABLE QString getSnapshotsDirectory() const;
    Q_INVOKABLE QString generateSnapshotFilename(const QString &cameraName) const;
    
signals:
    void snapshotSaved(const QString &filePath);
    void snapshotError(const QString &error);
};

#endif // SNAPSHOTHELPER_H

