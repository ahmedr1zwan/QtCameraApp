import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtCameraApp

Rectangle {
    id: tile
    property string cameraId: ""
    property string cameraName: "Camera"
    property bool isActive: false
    property int tileIndex: 0
    readonly property int currentFps: analyticsEngine.framesPerSecond
    property bool motionDetectionEnabled: false
    property double motionSensitivity: 0.55
    property bool objectDetectionEnabled: false
    property string yoloModelPath: ""
    property string yoloLabelsPath: ":/QtCameraApp/assets/coco.names"
    property double objectConfidenceThreshold: 0.45
    property bool tripwireDrawingMode: false
    property bool roiDrawingMode: false
    property bool deleteMode: false  // Enable delete mode to remove tripwires/ROIs
    property var tileTripwireManager: null  // Will be set from parent
    
    // Dark Blue Theme Colors (matching Main.qml)
    readonly property color colorPrimary: "#1a2332"
    readonly property color colorSecondary: "#2d3a4f"
    readonly property color colorAccent: "#4a90e2"
    readonly property color colorAccentLight: "#5ba3f5"
    readonly property color colorText: "#e8f0f8"
    readonly property color colorTextSecondary: "#b0c4de"
    readonly property color colorBorder: "#3d4f66"
    readonly property color colorHover: "#3a4d6b"
    readonly property color colorSuccess: "#52c9a2"
    readonly property color colorWarning: "#f5a623"
    readonly property color colorError: "#e74c3c"
    readonly property color colorCard: "#253447"
    readonly property color colorCardAlt: "#1e2a3a"
    
    signal removeRequested()
    signal fullScreenRequested()
    signal addCameraRequested(int index)
    signal snapshotSaved(string filePath)
    signal snapshotError(string error)
    signal motionDetected(double level)
    signal analyticsEvent(string eventType, string description, string snapshotPath)
    signal tripwireCrossed(string tripwireId)
    signal roiEntered(string roiId)
    signal drawingModeChanged(int tileIndex, bool enabled)  // Signal when drawing mode changes
    
    function takeSnapshot() {
        if (!camera.active) {
            console.log("Cannot take snapshot: camera is not active")
            return
        }
        
        var filePath = snapshotHelper.generateSnapshotFilename(cameraName)
        console.log("Taking snapshot, saving to:", filePath)
        imageCapture.captureToFile(filePath)
    }

    property bool eventCapturePending: false
    property string pendingEventType: ""
    property string pendingEventDescription: ""

    function recordEvent(eventType, description) {
        if (!camera.active || eventCapturePending) {
            analyticsEvent(eventType, description, "")
            return
        }
        eventCapturePending = true
        pendingEventType = eventType
        pendingEventDescription = description
        imageCapture.captureToFile(snapshotHelper.generateSnapshotFilename(cameraName + "_" + eventType))
    }

    function evaluateBoundaryPoint(currentPoint, sourceKey) {
        if (!tileTripwireManager || currentPoint.x < 0 || currentPoint.y < 0)
            return

        var tileId = "tile_" + tile.tileIndex
        var previous = trackedPoints[sourceKey]
        if (previous) {
            var tripwires = tileTripwireManager.getAllTripwires(tileId)
            for (var i = 0; i < tripwires.length; ++i) {
                if (tripwires[i].enabled
                        && tileTripwireManager.checkTripwireCrossing(
                            tripwires[i].id, previous, currentPoint)) {
                    tile.tripwireCrossed(tripwires[i].id)
                }
            }
        }
        trackedPoints[sourceKey] = currentPoint

        var rois = tileTripwireManager.getAllROIs(tileId)
        for (var j = 0; j < rois.length; ++j) {
            if (rois[j].enabled
                    && tileTripwireManager.checkROIEntry(rois[j].id, currentPoint)) {
                tile.roiEntered(rois[j].id)
            }
        }
    }

    property var trackedPoints: ({})
    
    // Visual feedback for snapshot
    property bool snapshotFlash: false
    
    Rectangle {
        id: snapshotFlashOverlay
        anchors.fill: parent
        color: "white"
        opacity: snapshotFlash ? 0.8 : 0
        visible: snapshotFlash
        z: 1000
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Connections {
        target: imageCapture
        function onImageSaved(id, path) {
            if (tile.eventCapturePending) {
                tile.analyticsEvent(tile.pendingEventType, tile.pendingEventDescription, path)
                tile.eventCapturePending = false
                tile.pendingEventType = ""
                tile.pendingEventDescription = ""
            } else {
                tile.snapshotSaved(path)
            }
            tile.snapshotFlash = true
            flashTimer.start()
        }
        function onErrorOccurred(id, error, errorString) {
            if (tile.eventCapturePending) {
                tile.analyticsEvent(tile.pendingEventType, tile.pendingEventDescription, "")
                tile.eventCapturePending = false
            }
            tile.snapshotError(errorString)
        }
    }
    
    Timer {
        id: flashTimer
        interval: 200
        onTriggered: {
            tile.snapshotFlash = false
        }
    }
    
    color: colorCard
    border.color: analyticsEngine.motionDetected ? colorError : colorBorder
    border.width: analyticsEngine.motionDetected ? 3 : 1
    radius: 8
    
    // Motion detection indicator overlay
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: colorError
        border.width: 3
        radius: 8
        visible: analyticsEngine.motionDetected
        opacity: 0.6
        
        SequentialAnimation on opacity {
            running: analyticsEngine.motionDetected
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 500 }
            NumberAnimation { to: 0.6; duration: 500 }
        }
    }
    
    // MediaDevices to access camera list
    MediaDevices {
        id: mediaDevices
    }
    
    // Camera component
    Camera {
        id: camera
        active: tile.isActive && cameraPermissionHelper.hasPermission && cameraId !== ""
        
        function updateCameraDevice() {
            if (!cameraId || cameraId === "") {
                // Don't set cameraDevice to null - just return
                // The camera will be inactive due to the active property binding
                return
            }
            
            console.log("Looking for camera with ID:", cameraId, "Type:", typeof cameraId)
            var devices = mediaDevices.videoInputs
            console.log("Available devices count:", devices.length)
            
            for (var i = 0; i < devices.length; i++) {
                var device = devices[i]
                var deviceId = String(device.id)
                
                console.log("Device", i, ":", device.description, "| ID:", deviceId, "| ID type:", typeof device.id)
                
                // Try exact match first
                if (deviceId === cameraId) {
                    camera.cameraDevice = device
                    console.log("✓ Camera device matched and set:", device.description)
                    return
                }
                
                // Try trimming and comparing (in case of whitespace issues)
                if (deviceId.trim() === cameraId.trim()) {
                    camera.cameraDevice = device
                    console.log("✓ Camera device matched (trimmed) and set:", device.description)
                    return
                }
            }
            console.log("✗ Camera device not found for ID:", cameraId)
            console.log("Available IDs were:")
            for (var j = 0; j < devices.length; j++) {
                console.log("  -", String(devices[j].id))
            }
        }
    }
    
    // Update camera device when cameraId changes
    onCameraIdChanged: {
        if (cameraId && cameraId !== "") {
            camera.updateCameraDevice()
        } else {
            // Reset motion detection state when camera is removed
            motionDetectionEnabled = false
            tripwireDrawingMode = false
            roiDrawingMode = false
            deleteMode = false
            trackedPoints = ({})
        }
        // When cameraId is empty, camera will be inactive automatically
        // due to the active property binding, so we don't need to set cameraDevice
    }
    
    Component.onCompleted: {
        if (cameraId && cameraId !== "") {
            camera.updateCameraDevice()
        }
        // Set focus if in drawing mode to capture Escape key
        if (tripwireDrawingMode || roiDrawingMode) {
            tile.forceActiveFocus()
        }
    }
    
    // Image capture for snapshots
    ImageCapture {
        id: imageCapture
        // Signal handlers are in Connections element above to avoid duplication
    }
    
    // Capture session
    CaptureSession {
        id: captureSession
        camera: camera
        videoOutput: videoOutput
        imageCapture: imageCapture
    }
    
    AnalyticsEngine {
        id: analyticsEngine
        motionEnabled: tile.motionDetectionEnabled && camera.active
        objectDetectionEnabled: tile.objectDetectionEnabled && camera.active
        sensitivity: tile.motionSensitivity
        confidenceThreshold: tile.objectConfidenceThreshold
        modelPath: tile.yoloModelPath
        labelsPath: tile.yoloLabelsPath
        
        onMotionDetectedSignal: function(level) {
            console.log("Motion detected on", cameraName, "Level:", level)
            tile.motionDetected(level)
        }

        onObjectDetected: function(label, confidence, centerX, centerY) {
            var center = Qt.point(centerX, centerY)
            tile.evaluateBoundaryPoint(center, "object:" + label)
            tile.recordEvent("object", label + " detected (" + Math.round(confidence * 100) + "%)")
        }
        
        onMotionCentroidChanged: function(x, y) {
            var currentPoint = Qt.point(x, y)
            if (currentPoint.x >= 0 && currentPoint.y >= 0)
                tile.evaluateBoundaryPoint(currentPoint, "motion")
        }
    }
    
    // Video output
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        anchors.topMargin: 45  // Leave space for controls at top
        anchors.bottomMargin: 40  // Leave space for controls at bottom
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        fillMode: VideoOutput.PreserveAspectFit
        
        // Connect videoSink to motion detector
        Component.onCompleted: {
            connectVideoSink()
        }
        
        function connectVideoSink() {
            // Try to connect videoSink - it may not be available immediately
            if (videoSink) {
                analyticsEngine.setVideoSink(videoSink)
            } else {
                // Retry after a short delay if videoSink isn't ready yet
                videoSinkConnectTimer.start()
            }
        }
    }
    
    // Timer to retry connecting videoSink if it wasn't ready initially
    Timer {
        id: videoSinkConnectTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (videoOutput.videoSink) {
                analyticsEngine.setVideoSink(videoOutput.videoSink)
            }
        }
    }
    
    // Also connect when camera becomes active
    Connections {
        target: camera
        function onActiveChanged() {
            if (camera.active) {
                // Give it a moment for videoSink to be ready
                videoSinkConnectTimer.start()
            }
        }
    }
    
    // Tripwire/ROI overlay
    TripwireOverlay {
        id: tripwireOverlay
        x: videoOutput.x + videoOutput.contentRect.x
        y: videoOutput.y + videoOutput.contentRect.y
        width: videoOutput.contentRect.width
        height: videoOutput.contentRect.height
        tripwireManager: tileTripwireManager
        tileId: "tile_" + tile.tileIndex  // Use tileIndex instead of cameraId for tile-specific tripwires
        drawingMode: tile.tripwireDrawingMode || tile.roiDrawingMode
        drawingType: tile.tripwireDrawingMode ? "tripwire" : "roi"
        deleteMode: tile.deleteMode || false
        z: 50  // Below controls but above video
    }

    DetectionOverlay {
        x: videoOutput.x + videoOutput.contentRect.x
        y: videoOutput.y + videoOutput.contentRect.y
        width: videoOutput.contentRect.width
        height: videoOutput.contentRect.height
        detections: analyticsEngine.detections
        visible: tile.objectDetectionEnabled
        z: 45
    }
    
    // Overlay with controls
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "transparent"
        z: 200  // Above tripwire overlay
        
        // Top bar with title and controls - always visible, positioned outside video area
        Rectangle {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 45
            color: colorSecondary
            border.color: colorBorder
            border.width: 1
            visible: true  // Always visible, not hover-based
            z: 300  // Ensure controls are always clickable
            
            // Left side: Camera info with FPS always visible
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                
                Text {
                    text: cameraName
                    color: colorText
                    font.pixelSize: 15
                    font.bold: true
                }
                
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: camera.active ? colorSuccess : colorTextSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    visible: camera.active && currentFps > 0
                    text: currentFps + " FPS"
                    color: currentFps >= 25 ? colorSuccess : (currentFps >= 15 ? colorWarning : colorError)
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            
            // Right side: Control buttons with better spacing
            Row {
                id: controlButtons
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: true  // Always visible, not hover-based
                
                // Motion Detection Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: motionDetectionEnabled ? colorError : (parent.pressed ? colorHover : colorCard)
                        radius: 4
                        border.color: motionDetectionEnabled ? colorError : colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "🔴"
                        font.pixelSize: 14
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: motionDetectionEnabled ? "Disable Motion" : "Enable Motion"
                    onClicked: tile.motionDetectionEnabled = !tile.motionDetectionEnabled
                }

                Button {
                    width: 46
                    height: 32
                    enabled: camera.active && analyticsEngine.modelReady
                    background: Rectangle {
                        color: objectDetectionEnabled ? colorSuccess : (parent.pressed ? colorHover : colorCard)
                        radius: 4
                        border.color: objectDetectionEnabled ? colorSuccess : colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "YOLO"
                        color: colorText
                        font.pixelSize: 9
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: analyticsEngine.modelReady
                                  ? (objectDetectionEnabled ? "Disable object detection" : "Enable object detection")
                                  : analyticsEngine.modelStatus
                    onClicked: tile.objectDetectionEnabled = !tile.objectDetectionEnabled
                }
                
                // Tripwire Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: tripwireDrawingMode ? colorSuccess : (parent.pressed ? colorHover : colorCard)
                        radius: 4
                        border.color: tripwireDrawingMode ? colorSuccess : colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "─"
                        font.pixelSize: 16
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: "Draw Tripwire"
                    onClicked: {
                        tile.tripwireDrawingMode = !tile.tripwireDrawingMode
                        if (tile.tripwireDrawingMode) {
                            tile.roiDrawingMode = false
                            tile.deleteMode = false
                            tile.drawingModeChanged(tile.tileIndex, true)
                        } else {
                            tile.drawingModeChanged(tile.tileIndex, false)
                        }
                    }
                }
                
                // ROI Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: roiDrawingMode ? colorAccent : (parent.pressed ? colorHover : colorCard)
                        radius: 4
                        border.color: roiDrawingMode ? colorAccent : colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "▢"
                        font.pixelSize: 16
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: "Draw ROI"
                    onClicked: {
                        tile.roiDrawingMode = !tile.roiDrawingMode
                        if (tile.roiDrawingMode) {
                            tile.tripwireDrawingMode = false
                            tile.deleteMode = false
                            tile.drawingModeChanged(tile.tileIndex, true)
                        } else {
                            tile.drawingModeChanged(tile.tileIndex, false)
                        }
                    }
                }
                
                // Delete Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: deleteMode ? colorWarning : (parent.pressed ? colorHover : colorCard)
                        radius: 4
                        border.color: deleteMode ? colorWarning : colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "✂️"
                        font.pixelSize: 14
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: "Delete"
                    onClicked: {
                        tile.deleteMode = !tile.deleteMode
                        if (tile.deleteMode) {
                            tile.tripwireDrawingMode = false
                            tile.roiDrawingMode = false
                            tile.drawingModeChanged(tile.tileIndex, true)
                        } else {
                            tile.drawingModeChanged(tile.tileIndex, false)
                        }
                    }
                }
                
                // Snapshot Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: parent.pressed ? colorHover : colorCard
                        radius: 4
                        border.color: colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "📷"
                        font.pixelSize: 14
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: "Snapshot"
                    onClicked: tile.takeSnapshot()
                }
                
                // Fullscreen Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: parent.pressed ? colorHover : colorCard
                        radius: 4
                        border.color: colorBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "⛶"
                        font.pixelSize: 14
                        color: colorText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Fullscreen"
                    onClicked: tile.fullScreenRequested()
                }
                
                // Remove Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: parent.pressed ? colorError : colorError
                        radius: 4
                        border.color: colorError
                        border.width: 1
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: 16
                        color: colorText
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Remove"
                    onClicked: tile.removeRequested()
                }
            }
        }
        
        // Bottom bar with status - always visible, positioned outside video area
        Rectangle {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            color: colorSecondary
            border.color: colorBorder
            border.width: 1
            visible: true  // Always visible
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15
                
                Text {
                    text: "Status:"
                    color: colorTextSecondary
                    font.pixelSize: 11
                }
                
                Text {
                    text: camera.active ? "Active" : "Inactive"
                    color: camera.active ? colorSuccess : colorTextSecondary
                    font.pixelSize: 11
                    font.bold: true
                }
                
                Text {
                    visible: motionDetectionEnabled && analyticsEngine.motionLevel > 0
                    text: "• Motion: " + Math.round(analyticsEngine.motionLevel * 100) + "%"
                    color: analyticsEngine.motionDetected ? colorError : colorTextSecondary
                    font.pixelSize: 11
                    font.bold: analyticsEngine.motionDetected
                }

                Text {
                    visible: objectDetectionEnabled
                    text: "• Objects: " + analyticsEngine.detections.length
                    color: colorSuccess
                    font.pixelSize: 11
                    font.bold: true
                }
            }
            
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                
                // Motion sensitivity slider (only show when motion detection is enabled)
                Column {
                    visible: motionDetectionEnabled && camera.active
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1000  // Ensure slider is above other elements
                    
                    Text {
                        text: "Sensitivity: " + Math.round(motionSensitivity * 100) + "%"
                        color: colorTextSecondary
                        font.pixelSize: 10
                    }
                    
                    Slider {
                        id: sensitivitySlider
                        width: 120
                        height: 24  // Increased height for easier clicking
                        from: 0.1
                        to: 1.0
                        value: motionSensitivity
                        stepSize: 0.05
                        z: 1001  // Ensure slider is above other elements
                        
                        background: Rectangle {
                            x: sensitivitySlider.leftPadding
                            y: sensitivitySlider.topPadding + sensitivitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 120
                            implicitHeight: 6  // Track height
                            width: sensitivitySlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: colorCardAlt
                        }
                        handle: Rectangle {
                            x: sensitivitySlider.leftPadding + sensitivitySlider.visualPosition * (sensitivitySlider.availableWidth - width)
                            y: sensitivitySlider.topPadding + sensitivitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 18  // Larger handle for easier clicking
                            implicitHeight: 18
                            radius: 9
                            color: sensitivitySlider.pressed ? colorAccent : colorAccentLight
                            border.color: colorAccent
                            border.width: 2
                        }
                        onValueChanged: tile.motionSensitivity = value
                    }
                }
                
                Button {
                    width: 70
                    height: 28
                    background: Rectangle {
                        color: camera.active ? colorError : colorSuccess
                        radius: 4
                        border.color: camera.active ? colorError : colorSuccess
                        border.width: 1
                    }
                    contentItem: Text {
                        text: camera.active ? "Stop" : "Start"
                        color: colorText
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: tile.isActive = !tile.isActive
                }
            }
        }
    }
    
    // Mouse area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton  // Don't intercept clicks, only hover
    }
    
    // Handle Escape key to exit drawing mode
    Keys.onEscapePressed: {
        if (tripwireDrawingMode || roiDrawingMode || deleteMode) {
            tripwireDrawingMode = false
            roiDrawingMode = false
            deleteMode = false
            drawingModeChanged(tileIndex, false)
            console.log("Drawing mode disabled via Escape key")
        }
    }
    
    Connections {
        target: tile
        function onTripwireDrawingModeChanged() {
            if (tripwireDrawingMode || roiDrawingMode) {
                tile.forceActiveFocus()
            }
        }
        function onRoiDrawingModeChanged() {
            if (tripwireDrawingMode || roiDrawingMode) {
                tile.forceActiveFocus()
            }
        }
    }
    
    // Empty state
    Rectangle {
        anchors.fill: parent
        color: colorCardAlt
        border.color: colorBorder
        border.width: 1
        radius: 8
        visible: !cameraId || cameraId === ""
        
        Column {
            anchors.centerIn: parent
            spacing: 15
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "📷 No Camera"
                color: colorTextSecondary
                font.pixelSize: 18
                font.bold: true
            }
            
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "➕ Add Camera"
                background: Rectangle {
                    color: parent.pressed ? colorHover : colorAccent
                    radius: 5
                    border.color: colorAccent
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: colorText
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    tile.addCameraRequested(tile.tileIndex)
                }
            }
        }
    }
}
