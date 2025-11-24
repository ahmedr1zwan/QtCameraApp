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
    
    // Dark Blue Theme Colors
    readonly property color colorPrimary: "#1a2332"      // Dark blue background
    readonly property color colorSecondary: "#2d3a4f"    // Medium dark blue
    readonly property color colorAccent: "#4a90e2"      // Bright blue accent
    readonly property color colorAccentLight: "#5ba3f5" // Lighter blue
    readonly property color colorText: "#e8f0f8"        // Light text
    readonly property color colorTextSecondary: "#b0c4de" // Secondary text
    readonly property color colorBorder: "#3d4f66"      // Border color
    readonly property color colorHover: "#3a4d6b"      // Hover state
    readonly property color colorSuccess: "#52c9a2"     // Success green
    readonly property color colorWarning: "#f5a623"      // Warning orange
    readonly property color colorError: "#e74c3c"      // Error red
    readonly property color colorCard: "#253447"        // Card background
    readonly property color colorCardAlt: "#1e2a3a"     // Alternate card
    
    color: colorPrimary

    // Camera tiles data model
    ListModel {
        id: cameraTilesModel
    }
    
    // Camera selection dialog
    Dialog {
        id: cameraSelectDialog
        title: "Select Camera"
        width: 450
        height: 350
        anchors.centerIn: parent
        modal: true
        
        Column {
            anchors.fill: parent
            spacing: 15
            anchors.margins: 15
            
            Text {
                text: "📷 Available Cameras:"
                font.bold: true
                font.pixelSize: 16
                color: colorText
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
                    color: mouseArea.containsMouse ? colorHover : colorCard
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        
                        Text {
                            text: model.description || "Unknown Camera"
                            color: colorText
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
        modal: true
        
        Column {
            anchors.fill: parent
            spacing: 15
            anchors.margins: 15
            
            // Header with controls
            Row {
                width: parent.width
                spacing: 10
                
                Text {
                    text: "📊 Total Alerts: " + alertManager.alertCount
                    font.bold: true
                    font.pixelSize: 16
                    color: colorText
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
                    color: index % 2 === 0 ? colorCard : colorCardAlt
                    
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
                                    color: colorTextSecondary
                                    font.pixelSize: 10
                                }
                                
                                Text {
                                    text: "[" + (model.alertType || "") + "]"
                                    color: {
                                        if (model.alertType === "motion") return colorWarning
                                        if (model.alertType === "tripwire") return colorSuccess
                                        if (model.alertType === "roi") return colorWarning
                                        return colorAccent
                                    }
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                
                                Text {
                                    text: model.cameraName || "Unknown"
                                    color: colorText
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            Text {
                                text: model.description || ""
                                color: colorTextSecondary
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
        color: colorSecondary
        
        // Bottom border line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: colorBorder
        }
        
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20
            
            Text {
                text: "📹 Qt Camera Surveillance"
                color: colorText
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                text: "Cameras: " + cameraManager.availableCameraCount
                color: colorTextSecondary
                font.pixelSize: 12
            }
            
            Text {
                visible: !cameraPermissionHelper.hasPermission
                text: "⚠ Camera permission required"
                color: colorWarning
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
            
            Button {
                text: "Config"
                onClicked: configDialog.open()
            }
        }
    }
    
    // Camera Config Dialog
    Dialog {
        id: configDialog
        title: "Camera Configuration"
        width: 750
        height: 650
        anchors.centerIn: parent
        modal: true
        
        property var cameraListModel: ListModel {
            id: cameraListModel
        }
        
        function refreshCameraList() {
            cameraListModel.clear()
            var cameras = configManager.getAllCameras()
            for (var i = 0; i < cameras.length; i++) {
                var cam = cameras[i]
                cameraListModel.append({
                    name: cam.name || "Unnamed Camera",
                    deviceId: cam.deviceId || "",
                    url: cam.url || "",
                    enabled: cam.enabled !== undefined ? cam.enabled : true
                })
            }
        }
        
        onOpened: {
            refreshCameraList()
        }
        
        Connections {
            target: configManager
            function onCamerasChanged() {
                configDialog.refreshCameraList()
            }
        }
        
        Column {
            anchors.fill: parent
            spacing: 15
            anchors.margins: 20
            
            Text {
                text: "Camera Configurations"
                font.bold: true
                font.pixelSize: 18
                color: colorText
            }
            
            Text {
                text: "Config file: " + configManager.configFilePath
                font.pixelSize: 11
                color: colorTextSecondary
                wrapMode: Text.Wrap
            }
            
            Rectangle {
                width: parent.width
                height: 350
                color: colorCardAlt
                border.color: colorBorder
                border.width: 1
                radius: 5
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 5
                    clip: true
                    
                    ListView {
                        id: configCameraList
                        width: parent.width
                        model: cameraListModel
                        
                        delegate: Rectangle {
                            width: configCameraList.width
                            height: 80
                            color: index % 2 === 0 ? colorCard : colorCardAlt
                            
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 15
                                anchors.right: parent.right
                                anchors.rightMargin: 15
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 15
                                
                                Column {
                                    width: parent.width - 120
                                    spacing: 8
                                    
                                    Text {
                                        text: model.name
                                        color: colorText
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    
                                    Text {
                                        text: "Device ID: " + (model.deviceId || "N/A")
                                        color: colorTextSecondary
                                        font.pixelSize: 11
                                        elide: Text.ElideMiddle
                                    }
                                    
                                    Text {
                                        visible: model.url && model.url !== ""
                                        text: "URL: " + model.url
                                        color: colorTextSecondary
                                        font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                }
                                
                                Button {
                                    text: "Remove"
                                    width: 100
                                    onClicked: {
                                        configManager.removeCamera(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Text {
                text: "Cameras in config: " + configManager.cameraCount
                font.pixelSize: 12
                color: colorTextSecondary
            }
            
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter
                
                Button {
                    text: "➕ Add Camera"
                    onClicked: addCameraConfigDialog.open()
                }
                
                Button {
                    text: "💾 Save Config"
                    onClicked: {
                        if (configManager.saveConfig()) {
                            showSnapshotToast("Config saved successfully", true)
                        } else {
                            showSnapshotToast("Failed to save config", false)
                        }
                    }
                }
                
                Button {
                    text: "🔄 Load Config"
                    onClicked: {
                        if (configManager.loadConfig()) {
                            refreshCameraList()
                            loadCamerasFromConfig()
                            showSnapshotToast("Config loaded successfully", true)
                        } else {
                            showSnapshotToast("Failed to load config", false)
                        }
                    }
                }
                
                Button {
                    text: "Close"
                    onClicked: configDialog.close()
                }
            }
        }
    }
    
    // Add Camera Config Dialog
    Dialog {
        id: addCameraConfigDialog
        title: "Add Camera to Config"
        width: 700
        height: 650
        anchors.centerIn: parent
        modal: true
        
        onOpened: {
            // Refresh camera list when dialog opens
            cameraManager.refreshCameras()
            cameraSelectCombo.currentIndex = -1
            configCameraNameField.text = ""
            configDeviceIdField.text = ""
            configUrlField.text = ""
        }
        
        ScrollView {
            anchors.fill: parent
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            
            Column {
                width: addCameraConfigDialog.width - 40
                spacing: 15
                anchors.margins: 20
                
                Text {
                    text: "Add Camera to Configuration"
                    font.pixelSize: 16
                    font.bold: true
                    color: colorText
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: colorBorder
                }
            
                Text {
                    text: "Step 1: Select a camera from the list below"
                    font.pixelSize: 12
                    color: colorTextSecondary
                }
            
            ComboBox {
                id: cameraSelectCombo
                width: parent.width
                height: 40
                model: cameraManager
                
                displayText: currentIndex >= 0 
                    ? cameraManager.getCameraDescription(currentIndex)
                    : "📷 Select a camera..."
                
                delegate: ItemDelegate {
                    width: cameraSelectCombo.width
                    text: model.description || "Unknown Camera"
                    highlighted: cameraSelectCombo.highlightedIndex === index
                }
                
                onActivated: function(index) {
                    if (index >= 0 && index < cameraManager.availableCameraCount) {
                        var selectedId = cameraManager.getCameraId(index)
                        var selectedName = cameraManager.getCameraDescription(index)
                        configDeviceIdField.text = selectedId
                        configCameraNameField.text = selectedName
                        console.log("Selected camera:", selectedName, "ID:", selectedId)
                    }
                }
            }
            
                Row {
                    spacing: 10
                    
                    Text {
                        text: "Available: " + cameraManager.availableCameraCount + " cameras"
                        font.pixelSize: 11
                        color: colorTextSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Button {
                        text: "🔄 Refresh"
                        onClicked: {
                            cameraManager.refreshCameras()
                            cameraSelectCombo.currentIndex = -1
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: colorBorder
                }
                
                Text {
                    text: "Step 2: Review and edit camera details"
                    font.pixelSize: 12
                    color: colorTextSecondary
                }
                
                Text {
                    text: "Camera Name:"
                    font.pixelSize: 12
                    font.bold: true
                    color: colorText
                }
                
                TextField {
                    id: configCameraNameField
                    width: parent.width
                    placeholderText: "Camera name (auto-filled when selected)"
                }
                
                Text {
                    text: "Device ID:"
                    font.pixelSize: 12
                    font.bold: true
                    color: colorText
                }
                
                TextField {
                    id: configDeviceIdField
                    width: parent.width
                    placeholderText: "Device ID (auto-filled when selected)"
                    readOnly: true
                }
                
                Text {
                    text: "URL (optional, for IP cameras):"
                    font.pixelSize: 12
                    color: colorTextSecondary
                }
                
                TextField {
                    id: configUrlField
                    width: parent.width
                    placeholderText: "e.g., rtsp://192.168.1.100:554/stream"
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: colorBorder
                }
            
            Row {
                spacing: 10
                anchors.right: parent.right
                
                Button {
                    text: "✅ Add to Config"
                    onClicked: {
                        var name = configCameraNameField.text.trim()
                        var deviceId = configDeviceIdField.text.trim()
                        var url = configUrlField.text.trim()
                        
                        if (deviceId === "") {
                            showSnapshotToast("❌ Please select a camera from the dropdown", false)
                            return
                        }
                        
                        if (name === "") {
                            name = "Camera " + (configManager.cameraCount + 1)
                        }
                        
                        console.log("Adding camera to config:", name, deviceId, url)
                        configManager.addCamera(name, url, deviceId)
                        
                        // Clear fields
                        configCameraNameField.text = ""
                        configDeviceIdField.text = ""
                        configUrlField.text = ""
                        cameraSelectCombo.currentIndex = -1
                        
                        addCameraConfigDialog.close()
                        showSnapshotToast("✅ Camera added to config", true)
                    }
                }
                
                Button {
                    text: "Cancel"
                    onClicked: addCameraConfigDialog.close()
                }
            }
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
        color: colorSecondary
        border.color: colorBorder
        border.width: 1
        radius: 5
        opacity: 0
        visible: opacity > 0
        z: 1000
        
        Row {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                text: toastNotification.text || ""
                color: colorText
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
        toastNotification.color = isSuccess ? colorSecondary : colorError
        toastNotification.opacity = 1
        toastTimer.restart()
    }
    
    function showAlertToast(message) {
        toastNotification.text = "⚠ " + message
        toastNotification.color = colorWarning
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
        
        // Load cameras from config if available
        loadCamerasFromConfig()
    }
    
    function loadCamerasFromConfig() {
        if (configManager.configFileExists()) {
            var cameras = configManager.getAllCameras()
            console.log("Loading", cameras.length, "cameras from config")
            for (var i = 0; i < cameras.length && i < 4; i++) {
                var cam = cameras[i]
                // For now, we only support deviceId (local cameras)
                // URL support for IP cameras can be added later
                if (cam.deviceId && cam.deviceId !== "") {
                    addCameraToGrid(cam.deviceId, cam.name || ("Camera " + (i + 1)), i)
                }
            }
        }
    }
    
    // Functions
    function addCameraToGrid(cameraId, cameraName, tileIndex) {
        if (tileIndex >= 0 && tileIndex < cameraTilesModel.count) {
            cameraTilesModel.setProperty(tileIndex, "cameraId", cameraId)
            cameraTilesModel.setProperty(tileIndex, "cameraName", cameraName)
            cameraTilesModel.setProperty(tileIndex, "isActive", true)
            
            // Optionally save to config (user can disable this if they want)
            // For now, we'll let users manage config manually via the Config dialog
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
        
        // Close existing full-screen window if any
        if (fullScreenWindow) {
            fullScreenWindow.close()
            fullScreenWindow.destroy()
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
                    fullScreenWindow.destroy()
                    fullScreenWindow = null
                })
            }
        } else {
            console.log("Error loading FullScreenView:", component.errorString())
        }
    }
}
