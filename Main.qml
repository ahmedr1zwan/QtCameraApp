import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtMultimedia
import QtCameraApp

ApplicationWindow {
    id: window
    width: 1600
    height: 900
    visible: true
    title: qsTr("Qt Camera Surveillance - Multi-Camera Grid")

    // Camera tiles data model
    ListModel {
        id: cameraTilesModel
    }
    
    // Camera selection dialog
    Dialog {
        id: cameraSelectDialog
        title: "Select Camera"
        width: 400
        height: 300
        anchors.centerIn: parent
        
        Column {
            anchors.fill: parent
            spacing: 10
            
            Text {
                text: "Available Cameras:"
                font.bold: true
                font.pixelSize: 14
            }
            
            ListView {
                id: cameraListView
                width: parent.width
                height: 200
                model: cameraManager
                clip: true
                
                delegate: Rectangle {
                    width: cameraListView.width
                    height: 40
                    color: mouseArea.containsMouse ? "#333333" : "#222222"
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        
                        Text {
                            text: model.description || "Unknown Camera"
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            addCameraToGrid(model.cameraId, model.description, cameraSelectDialog.tileIndex)
                            cameraSelectDialog.close()
                        }
                    }
                }
            }
            
            Button {
                text: "Refresh"
                onClicked: {
                    console.log("Refresh cameras clicked")
                    cameraManager.refreshCameras()
                    // Force ListView to update
                    cameraListView.model = null
                    cameraListView.model = cameraManager
                }
            }
            
            Button {
                text: "Cancel"
                onClicked: cameraSelectDialog.close()
            }
        }
        
        property int tileIndex: -1
    }
    
    // Alert log dialog
    Dialog {
        id: alertLogDialog
        title: "Alert Log"
        width: 800
        height: 600
        anchors.centerIn: parent
        
        Column {
            anchors.fill: parent
            spacing: 10
            
            // Header with controls
            Row {
                width: parent.width
                spacing: 10
                
                Text {
                    text: "Total Alerts: " + alertManager.alertCount
                    font.bold: true
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { width: 20; height: 1 }  // Spacer
                
                Button {
                    text: "Export CSV"
                    onClicked: {
                        var path = alertManager.getDefaultExportPath() + "/alerts_" + 
                                   new Date().toISOString().replace(/:/g, "-").split(".")[0] + ".csv"
                        if (alertManager.exportToCSV(path)) {
                            showSnapshotToast("Exported to: " + path.split("/").pop(), true)
                        } else {
                            showSnapshotToast("Export failed", false)
                        }
                    }
                }
                
                Button {
                    text: "Export JSON"
                    onClicked: {
                        var path = alertManager.getDefaultExportPath() + "/alerts_" + 
                                   new Date().toISOString().replace(/:/g, "-").split(".")[0] + ".json"
                        if (alertManager.exportToJSON(path)) {
                            showSnapshotToast("Exported to: " + path.split("/").pop(), true)
                        } else {
                            showSnapshotToast("Export failed", false)
                        }
                    }
                }
                
                Button {
                    text: "Clear All"
                    onClicked: {
                        alertManager.clearAlerts()
                    }
                }
            }
            
            // Alert list
            ListView {
                id: alertListView
                width: parent.width
                height: parent.height - 60
                model: alertManager
                clip: true
                
                delegate: Rectangle {
                    width: alertListView.width
                    height: 60
                    color: index % 2 === 0 ? "#222222" : "#1a1a1a"
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15
                        
                        Column {
                            width: parent.width - 100
                            spacing: 5
                            
                            Row {
                                spacing: 10
                                
                                Text {
                                    text: model.timestamp || ""
                                    color: "#aaaaaa"
                                    font.pixelSize: 10
                                }
                                
                                Text {
                                    text: "[" + (model.alertType || "") + "]"
                                    color: {
                                        if (model.alertType === "motion") return "#ff6600"
                                        if (model.alertType === "tripwire") return "#00ff00"
                                        if (model.alertType === "roi") return "#ff6600"
                                        return "#66aaff"
                                    }
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                
                                Text {
                                    text: model.cameraName || "Unknown"
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            Text {
                                text: model.description || ""
                                color: "#cccccc"
                                font.pixelSize: 11
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Top status bar
    Rectangle {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#2b2b2b"
        
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20
            
            Text {
                text: "Qt Camera Surveillance"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                text: "Cameras: " + cameraManager.availableCameraCount
                color: "#aaaaaa"
                font.pixelSize: 12
            }
            
            Text {
                visible: !cameraPermissionHelper.hasPermission
                text: "⚠ Camera permission required"
                color: "orange"
                font.pixelSize: 12
            }
        }
        
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            
            Button {
                visible: !cameraPermissionHelper.hasPermission
                text: "Request Camera Permission"
                onClicked: cameraPermissionHelper.requestPermission()
            }
            
            Button {
                text: "Refresh Cameras"
                onClicked: {
                    console.log("Refresh cameras clicked from status bar")
                    cameraManager.refreshCameras()
                }
            }
            
            Button {
                text: "Alerts (" + alertManager.alertCount + ")"
                onClicked: alertLogDialog.open()
            }
        }
    }

    // Main grid area
    GridView {
        id: cameraGrid
        anchors.top: statusBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        
        cellWidth: width / 2
        cellHeight: height / 2
        
        model: cameraTilesModel
        
        delegate: CameraTile {
            id: cameraTileDelegate
            width: cameraGrid.cellWidth - 5
            height: cameraGrid.cellHeight - 5
            cameraId: model.cameraId || ""
            cameraName: model.cameraName || "Camera " + (index + 1)
            isActive: model.isActive || false
            tileIndex: index
            tileTripwireManager: tripwireManager
            
            onRemoveRequested: function() {
                console.log("Remove requested for tile index:", tileIndex)
                removeCameraFromGrid(tileIndex)
            }
            
            onFullScreenRequested: function() {
                console.log("Full screen requested for tile", index)
                openFullScreenView(model.cameraId, model.cameraName || "Camera " + (index + 1))
            }
            
            onAddCameraRequested: function(tileIdx) {
                openCameraSelector(tileIdx)
            }
            
            onDrawingModeChanged: function(tileIdx, enabled) {
                // When one tile enters drawing mode, disable it on all other tiles
                if (enabled && tileIdx === index) {
                    disableDrawingModeOnOtherTiles(tileIdx)
                }
            }
            
            onSnapshotSaved: function(filePath) {
                showSnapshotToast("Snapshot saved: " + filePath.split("/").pop(), true)
            }
            
            onSnapshotError: function(error) {
                showSnapshotToast("Snapshot error: " + error, false)
            }
            
            onMotionDetected: function(level) {
                // Take snapshot automatically when motion is detected
                var snapshotPath = snapshotHelper.generateSnapshotFilename(model.cameraName || "Camera")
                // Note: We can't directly capture here, but we can log the alert
                // The snapshot would need to be triggered separately
                alertManager.addAlert(
                    model.cameraName || "Camera " + (index + 1),
                    model.cameraId || "",
                    "motion",
                    "Motion detected: " + Math.round(level * 100) + "%",
                    ""  // Snapshot path would go here if we auto-capture
                )
                showAlertToast("Motion detected on " + (model.cameraName || "Camera"))
            }
            
            onTripwireCrossed: function(tripwireId) {
                alertManager.addAlert(
                    model.cameraName || "Camera " + (index + 1),
                    model.cameraId || "",
                    "tripwire",
                    "Tripwire crossed: " + tripwireId,
                    ""
                )
                showAlertToast("Tripwire crossed on " + (model.cameraName || "Camera"))
            }
            
            onRoiEntered: function(roiId) {
                alertManager.addAlert(
                    model.cameraName || "Camera " + (index + 1),
                    model.cameraId || "",
                    "roi",
                    "Motion entered ROI: " + roiId,
                    ""
                )
                showAlertToast("ROI entered on " + (model.cameraName || "Camera"))
            }
        }
    }
    
    // Toast notification for snapshots
    Rectangle {
        id: toastNotification
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: statusBar.bottom
        anchors.topMargin: 20
        width: 400
        height: 50
        color: "#2b2b2b"
        radius: 5
        opacity: 0
        visible: opacity > 0
        z: 1000
        
        Row {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                text: toastNotification.text || ""
                color: "white"
                font.pixelSize: 14
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        property string text: ""
    }
    
    Timer {
        id: toastTimer
        interval: 3000
        onTriggered: {
            toastNotification.opacity = 0
        }
    }
    
    function showSnapshotToast(message, isSuccess) {
        toastNotification.text = message
        toastNotification.color = isSuccess ? "#2b2b2b" : "#8b0000"
        toastNotification.opacity = 1
        toastTimer.restart()
    }
    
    function showAlertToast(message) {
        toastNotification.text = "⚠ " + message
        toastNotification.color = "#ff6600"
        toastNotification.opacity = 1
        toastTimer.restart()
    }
    
    // Initialize with 4 empty tiles
    Component.onCompleted: {
        for (let i = 0; i < 4; i++) {
            cameraTilesModel.append({
                cameraId: "",
                cameraName: "",
                isActive: false
            })
        }
    }
    
    // Functions
    function addCameraToGrid(cameraId, cameraName, tileIndex) {
        if (tileIndex >= 0 && tileIndex < cameraTilesModel.count) {
            cameraTilesModel.setProperty(tileIndex, "cameraId", cameraId)
            cameraTilesModel.setProperty(tileIndex, "cameraName", cameraName)
            cameraTilesModel.setProperty(tileIndex, "isActive", true)
        }
    }
    
    function removeCameraFromGrid(index) {
        console.log("removeCameraFromGrid called with index:", index, "Model count:", cameraTilesModel.count)
        if (index >= 0 && index < cameraTilesModel.count) {
            // Clear tripwires/ROIs for this tile when camera is removed
            var tileId = "tile_" + index
            tripwireManager.clearTripwiresForCamera(tileId)
            tripwireManager.clearROIsForCamera(tileId)
            
            cameraTilesModel.setProperty(index, "cameraId", "")
            cameraTilesModel.setProperty(index, "cameraName", "")
            cameraTilesModel.setProperty(index, "isActive", false)
            console.log("Camera removed from tile", index)
        } else {
            console.log("Invalid index for removeCameraFromGrid:", index)
        }
    }
    
    function openCameraSelector(tileIndex) {
        cameraSelectDialog.tileIndex = tileIndex
        cameraSelectDialog.open()
    }
    
    function disableDrawingModeOnOtherTiles(activeTileIndex) {
        // Disable drawing mode on all tiles except the active one
        for (var i = 0; i < cameraTilesModel.count; i++) {
            if (i !== activeTileIndex) {
                var tile = cameraGrid.itemAtIndex(i)
                if (tile) {
                    tile.tripwireDrawingMode = false
                    tile.roiDrawingMode = false
                    tile.deleteMode = false
                }
            }
        }
    }
    
    // Full-screen view component
    property var fullScreenWindow: null
    
    function openFullScreenView(cameraId, cameraName) {
        if (!cameraId || cameraId === "") {
            console.log("Cannot open full screen: no camera ID")
            return
        }
        // Find tile index that uses this cameraId (if any)
        var tileIndex = -1
        for (var i = 0; i < cameraTilesModel.count; i++) {
            if (cameraTilesModel.get(i).cameraId === cameraId) {
                tileIndex = i
                break
            }
        }
          if (tileIndex !== -1) {
            cameraTilesModel.setProperty(tileIndex, "isActive", false)
        }

        // Close existing full-screen window if any
        if (fullScreenWindow) {
            fullScreenWindow.close()
            fullScreenWindow.destroy()
            fullScreenWindow = null
        }
        
        // Create and show full-screen window
        var component = Qt.createComponent("qrc:/QtCameraApp/FullScreenView.qml")
        if (component.status === Component.Ready) {
            fullScreenWindow = component.createObject(window, {
                "cameraId": cameraId,
                "cameraName": cameraName
            })
            if (fullScreenWindow) {
                fullScreenWindow.show()
                fullScreenWindow.closing.connect(function() {
                    // Only restart if the tile still has the same camera assigned
                    if ((tileIndex !== -1) && (cameraTilesModel.get(tileIndex).cameraId === cameraId)) {
                        cameraTilesModel.setProperty(tileIndex, "isActive", true)
                    }
                    fullScreenWindow.destroy()
                    fullScreenWindow = null
                })
            }
        } else {
            console.log("Error loading FullScreenView:", component.errorString())
        }
    }
}
