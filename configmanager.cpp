#include "configmanager.h"
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDebug>

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
{
    // Set default config path
    m_configFilePath = getDefaultConfigPath();
}

QString ConfigManager::getDefaultConfigPath()
{
    // Use application data directory
    QString appDataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir;
    if (!dir.exists(appDataDir)) {
        dir.mkpath(appDataDir);
    }
    return appDataDir + "/cameras.json";
}

void ConfigManager::setConfigFilePath(const QString &path)
{
    if (m_configFilePath != path) {
        m_configFilePath = path;
        emit configFilePathChanged();
    }
}

void ConfigManager::addCamera(const QString &name, const QString &url, const QString &deviceId)
{
    QVariantMap camera;
    camera["name"] = name;
    camera["url"] = url;
    camera["deviceId"] = deviceId;
    camera["enabled"] = true;
    
    m_cameras.append(camera);
    emit camerasChanged();
}

void ConfigManager::removeCamera(int index)
{
    if (index >= 0 && index < m_cameras.size()) {
        m_cameras.removeAt(index);
        emit camerasChanged();
    }
}

void ConfigManager::updateCamera(int index, const QString &name, const QString &url, const QString &deviceId)
{
    if (index >= 0 && index < m_cameras.size()) {
        m_cameras[index]["name"] = name;
        m_cameras[index]["url"] = url;
        m_cameras[index]["deviceId"] = deviceId;
        emit camerasChanged();
    }
}

QVariantMap ConfigManager::getCamera(int index) const
{
    if (index >= 0 && index < m_cameras.size()) {
        return m_cameras[index];
    }
    return QVariantMap();
}

QVariantList ConfigManager::getAllCameras() const
{
    QVariantList result;
    for (const QVariantMap &camera : m_cameras) {
        result.append(camera);
    }
    return result;
}

bool ConfigManager::configFileExists() const
{
    return QFile::exists(m_configFilePath);
}

void ConfigManager::ensureConfigDirectory() const
{
    QFileInfo fileInfo(m_configFilePath);
    QDir dir = fileInfo.dir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }
}

bool ConfigManager::loadConfig()
{
    if (!configFileExists()) {
        qDebug() << "Config file does not exist:" << m_configFilePath;
        return false;
    }

    QFile file(m_configFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open config file for reading:" << m_configFilePath;
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError) {
        qWarning() << "Failed to parse config JSON:" << error.errorString();
        return false;
    }

    if (!doc.isObject()) {
        qWarning() << "Config file is not a valid JSON object";
        return false;
    }

    QJsonObject root = doc.object();
    QJsonArray camerasArray = root["cameras"].toArray();

    m_cameras.clear();
    for (const QJsonValue &value : camerasArray) {
        QJsonObject cameraObj = value.toObject();
        QVariantMap camera;
        camera["name"] = cameraObj["name"].toString();
        camera["url"] = cameraObj["url"].toString();
        camera["deviceId"] = cameraObj["deviceId"].toString();
        camera["enabled"] = cameraObj["enabled"].toBool(true);
        m_cameras.append(camera);
    }

    qDebug() << "Loaded" << m_cameras.size() << "cameras from config";
    emit camerasChanged();
    emit configLoaded();
    return true;
}

bool ConfigManager::saveConfig()
{
    ensureConfigDirectory();

    QJsonObject root;
    QJsonArray camerasArray;

    for (const QVariantMap &camera : m_cameras) {
        QJsonObject cameraObj;
        cameraObj["name"] = camera["name"].toString();
        cameraObj["url"] = camera["url"].toString();
        cameraObj["deviceId"] = camera["deviceId"].toString();
        cameraObj["enabled"] = camera.value("enabled", true).toBool();
        camerasArray.append(cameraObj);
    }

    root["cameras"] = camerasArray;
    root["version"] = "1.0";

    QJsonDocument doc(root);
    QFile file(m_configFilePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to open config file for writing:" << m_configFilePath;
        return false;
    }

    file.write(doc.toJson());
    file.close();

    qDebug() << "Saved" << m_cameras.size() << "cameras to config:" << m_configFilePath;
    emit configSaved();
    return true;
}

