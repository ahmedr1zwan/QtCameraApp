#include "alertmanager.h"
#include "tripwiremanager.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class CoreTests final : public QObject
{
    Q_OBJECT

private slots:
    void tripwireDetectsBoundedCrossing();
    void roiEmitsOnEntryOnly();
    void alertExportsAreStructuredAndEscaped();
};

void CoreTests::tripwireDetectsBoundedCrossing()
{
    TripwireManager manager;
    const QString id = manager.addTripwire("tile_0", {0.5, 0.0}, {0.5, 1.0});
    QSignalSpy spy(&manager, &TripwireManager::tripwireCrossed);

    QVERIFY(manager.checkTripwireCrossing(id, {0.25, 0.5}, {0.75, 0.5}));
    QCOMPARE(spy.count(), 1);
    QVERIFY(!manager.checkTripwireCrossing(id, {0.2, 0.2}, {0.3, 0.3}));
}

void CoreTests::roiEmitsOnEntryOnly()
{
    TripwireManager manager;
    const QVariantList polygon{
        QVariantMap{{"x", 0.2}, {"y", 0.2}},
        QVariantMap{{"x", 0.8}, {"y", 0.2}},
        QVariantMap{{"x", 0.8}, {"y", 0.8}},
        QVariantMap{{"x", 0.2}, {"y", 0.8}}
    };
    const QString id = manager.addROI("tile_0", polygon);
    QSignalSpy spy(&manager, &TripwireManager::roiEntered);

    QVERIFY(manager.checkROIEntry(id, {0.5, 0.5}));
    QVERIFY(!manager.checkROIEntry(id, {0.6, 0.6}));
    QCOMPARE(spy.count(), 1);
    QVERIFY(!manager.checkROIEntry(id, {0.9, 0.9}));
}

void CoreTests::alertExportsAreStructuredAndEscaped()
{
    AlertManager manager;
    manager.addAlert("Front, door", "camera-1", "object",
                     "person \"detected\"", "/tmp/evidence.jpg");
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString csvPath = directory.filePath("events.csv");
    const QString jsonPath = directory.filePath("events.json");
    QVERIFY(manager.exportToCSV(csvPath));
    QVERIFY(manager.exportToJSON(jsonPath));

    QFile csv(csvPath);
    QVERIFY(csv.open(QIODevice::ReadOnly | QIODevice::Text));
    const QByteArray csvData = csv.readAll();
    QVERIFY(csvData.contains("\"Front, door\""));
    QVERIFY(csvData.contains("\"person \"\"detected\"\"\""));

    QFile json(jsonPath);
    QVERIFY(json.open(QIODevice::ReadOnly));
    const QJsonObject root = QJsonDocument::fromJson(json.readAll()).object();
    QCOMPARE(root.value("totalAlerts").toInt(), 1);
    QCOMPARE(root.value("alerts").toArray().first().toObject().value("cameraId").toString(),
             QString("camera-1"));
}

QTEST_GUILESS_MAIN(CoreTests)
#include "test_core.moc"
