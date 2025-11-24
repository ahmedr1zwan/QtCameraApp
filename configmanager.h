#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class ConfigManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString configFilePath READ configFilePath WRITE setConfigFilePath NOTIFY configFilePathChanged)
    Q_PROPERTY(int cameraCount READ cameraCount NOTIFY camerasChanged)

public:
    explicit ConfigManager(QObject *parent = nullptr);

    QString configFilePath() const { return m_configFilePath; }
    void setConfigFilePath(const QString &path);

    int cameraCount() const { return m_cameras.size(); }

    // Camera config management
    Q_INVOKABLE void addCamera(const QString &name, const QString &url = "", const QString &deviceId = "");
    Q_INVOKABLE void removeCamera(int index);
    Q_INVOKABLE void updateCamera(int index, const QString &name, const QString &url = "", const QString &deviceId = "");
    Q_INVOKABLE QVariantMap getCamera(int index) const;
    Q_INVOKABLE QVariantList getAllCameras() const;

    // File operations
    Q_INVOKABLE bool loadConfig();
    Q_INVOKABLE bool saveConfig();
    Q_INVOKABLE bool configFileExists() const;

    // Get default config path
    static QString getDefaultConfigPath();

signals:
    void configFilePathChanged();
    void camerasChanged();
    void configLoaded();
    void configSaved();

private:
    QString m_configFilePath;
    QList<QVariantMap> m_cameras;

    void ensureConfigDirectory() const;
};

#endif // CONFIGMANAGER_H

