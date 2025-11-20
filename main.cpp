#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtQml/qqmlregistration.h>
#include <QQuickStyle>
#include "camerapermissionhelper.h"
#include "cameramanager.h"
#include "snapshothelper.h"
#include "motiondetector.h"
#include "alertmanager.h"
#include "tripwiremanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    // Set style to Basic to allow customization of buttons and controls
    QQuickStyle::setStyle("Basic");

    // Create permission helper (will automatically check and request permission)
    CameraPermissionHelper permissionHelper;
    
    // Create camera manager
    CameraManager cameraManager;
    
    // Create snapshot helper
    SnapshotHelper snapshotHelper;
    
    // Create alert manager
    AlertManager alertManager;
    
    // Create tripwire/ROI manager (one per camera tile, but we'll create a global one for now)
    // In a full implementation, each tile would have its own manager
    TripwireManager tripwireManager;
    
    QQmlApplicationEngine engine;
    
    // Register types for QML
    qmlRegisterType<MotionDetector>("QtCameraApp", 1, 0, "MotionDetector");
    
    // Register helpers for QML
    engine.rootContext()->setContextProperty("cameraPermissionHelper", &permissionHelper);
    engine.rootContext()->setContextProperty("cameraManager", &cameraManager);
    engine.rootContext()->setContextProperty("snapshotHelper", &snapshotHelper);
    engine.rootContext()->setContextProperty("alertManager", &alertManager);
    engine.rootContext()->setContextProperty("tripwireManager", &tripwireManager);
    
    const QUrl url(QStringLiteral("qrc:/QtCameraApp/Main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
