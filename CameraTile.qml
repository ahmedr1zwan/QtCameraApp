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
    property int currentFps: 0
    property bool motionDetectionEnabled: false
    property double motionSensitivity: 0.3  // 0.0 to 1.0
    property bool tripwireDrawingMode: false
    property bool roiDrawingMode: false
    property bool deleteMode: false  // Enable delete mode to remove tripwires/ROIs
    property var tileTripwireManager: null  // Will be set from parent
    
    signal removeRequested()
    signal fullScreenRequested()
    signal addCameraRequested(int index)
    signal snapshotSaved(string filePath)
    signal snapshotError(string error)
    signal motionDetected(double level)
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
            console.log("Snapshot saved successfully:", path)
            tile.snapshotSaved(path)
            // Flash effect
            tile.snapshotFlash = true
            flashTimer.start()
        }
        function onErrorOccurred(id, error, errorString) {
            console.log("Snapshot error:", errorString)
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
    
    color: "#2a2a2a"
    border.color: motionDetector.motionDetected ? "#ff4444" : "#4a4a4a"
    border.width: motionDetector.motionDetected ? 3 : 1
    radius: 8
    
    // Motion detection indicator overlay
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#ef4444"
        border.width: 3
        radius: 8
        visible: motionDetector.motionDetected
        opacity: 0.6
        
        SequentialAnimation on opacity {
            running: motionDetector.motionDetected
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
        onImageSaved: function(id, path) {
            console.log("Snapshot saved:", path)
            snapshotSaved(path)
        }
        onErrorOccurred: function(id, error, errorString) {
            console.log("Snapshot error:", errorString)
            snapshotError(errorString)
        }
    }
    
    // Capture session
    CaptureSession {
        id: captureSession
        camera: camera
        videoOutput: videoOutput
        imageCapture: imageCapture
    }
    
    // Motion detector
    MotionDetector {
        id: motionDetector
        enabled: tile.motionDetectionEnabled && camera.active
        sensitivity: tile.motionSensitivity
        
        onMotionDetectedSignal: function(level) {
            console.log("Motion detected on", cameraName, "Level:", level)
            tile.motionDetected(level)
        }
        
        property var previousCentroid: Qt.point(0, 0)
        
        onMotionCentroidChanged: function(x, y) {
            // Check tripwire/ROI when motion is detected (with some filtering to prevent noise)
            // Relaxed conditions: only require motionDetected (which already has sensitivity threshold)
            if (tileTripwireManager && motionDetected) {
                var currentPoint = Qt.point(x, y)
                var prevPoint = previousCentroid
                
                // Only check if we have a valid previous point (not initial (0,0))
                if ((prevPoint.x > 0 || prevPoint.y > 0)) {
                    // Calculate distance moved - use a very small threshold (0.2% of screen) for tripwires
                    // This allows detection of slower movements while still filtering noise
                    var dx = currentPoint.x - prevPoint.x
                    var dy = currentPoint.y - prevPoint.y
                    var distance = Math.sqrt(dx * dx + dy * dy)
                    
                    // Check tripwires with relaxed threshold - any movement above 0.2% of screen
                    // The cooldown in tripwire manager will prevent spam
                    if (distance > 0.002) {
                        // Check all tripwires for this tile
                        var tileId = "tile_" + tile.tileIndex
                        var tripwires = tileTripwireManager.getAllTripwires(tileId)
                        for (var i = 0; i < tripwires.length; i++) {
                            var tw = tripwires[i]
                            if (tw.enabled) {
                                if (tileTripwireManager.checkTripwireCrossing(tw.id, prevPoint, currentPoint)) {
                                    tile.tripwireCrossed(tw.id)
                                }
                            }
                        }
                    }
                }
                
                // Check all ROIs for this tile (always check when motion detected)
                var tileId = "tile_" + tile.tileIndex
                var rois = tileTripwireManager.getAllROIs(tileId)
                for (var j = 0; j < rois.length; j++) {
                    var roi = rois[j]
                    if (roi.enabled) {
                        if (tileTripwireManager.checkROIEntry(roi.id, currentPoint)) {
                            tile.roiEntered(roi.id)
                        }
                    }
                }
                
                // Always update previous centroid for next check
                previousCentroid = currentPoint
            }
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
                motionDetector.setVideoSink(videoSink)
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
                motionDetector.setVideoSink(videoOutput.videoSink)
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
    
    // FPS calculation timer
    Timer {
        id: fpsTimer
        interval: 1000  // Update every second
        running: camera.active
        repeat: true
        onTriggered: {
            // Estimate FPS based on camera status
            // Since we can't directly count frames, we'll show a reasonable estimate
            // or use a placeholder that indicates the camera is streaming
            if (camera.active && camera.cameraStatus === Camera.ActiveStatus) {
                // For now, show estimated FPS (typically 30 for most cameras)
                // In a real implementation, you'd count actual frame updates
                tile.currentFps = 30  // Placeholder - would need frame counting for accurate FPS
            } else {
                tile.currentFps = 0
            }
        }
    }
    
    // Start FPS timer when camera becomes active
    Connections {
        target: camera
        function onActiveChanged() {
            if (camera.active) {
                fpsTimer.start()
            } else {
                fpsTimer.stop()
                tile.currentFps = 0
            }
        }
    }
    
    // Tripwire/ROI overlay
    TripwireOverlay {
        id: tripwireOverlay
        anchors.fill: parent
        tripwireManager: tileTripwireManager
        tileId: "tile_" + tile.tileIndex  // Use tileIndex instead of cameraId for tile-specific tripwires
        drawingMode: tile.tripwireDrawingMode || tile.roiDrawingMode
        drawingType: tile.tripwireDrawingMode ? "tripwire" : "roi"
        deleteMode: tile.deleteMode || false
        z: 50  // Below controls but above video
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
            color: "#1e1e1e"
            border.color: "#3a3a3a"
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
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                }
                
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: camera.active ? "#4ade80" : "#6b7280"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    visible: camera.active && currentFps > 0
                    text: currentFps + " FPS"
                    color: currentFps >= 25 ? "#4ade80" : (currentFps >= 15 ? "#fbbf24" : "#f97316")
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
                        color: motionDetectionEnabled ? "#ef4444" : (parent.pressed ? "#4a4a4a" : "#3a3a3a")
                        radius: 4
                        border.color: motionDetectionEnabled ? "#dc2626" : "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "🔴"
                        font.pixelSize: 14
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    enabled: camera.active
                    ToolTip.visible: hovered
                    ToolTip.text: motionDetectionEnabled ? "Disable Motion" : "Enable Motion"
                    onClicked: tile.motionDetectionEnabled = !tile.motionDetectionEnabled
                }
                
                // Tripwire Button
                Button {
                    width: 36
                    height: 32
                    background: Rectangle {
                        color: tripwireDrawingMode ? "#10b981" : (parent.pressed ? "#4a4a4a" : "#3a3a3a")
                        radius: 4
                        border.color: tripwireDrawingMode ? "#059669" : "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "─"
                        font.pixelSize: 16
                        color: "white"
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
                        color: roiDrawingMode ? "#3b82f6" : (parent.pressed ? "#4a4a4a" : "#3a3a3a")
                        radius: 4
                        border.color: roiDrawingMode ? "#2563eb" : "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "▢"
                        font.pixelSize: 16
                        color: "white"
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
                        color: deleteMode ? "#f59e0b" : (parent.pressed ? "#4a4a4a" : "#3a3a3a")
                        radius: 4
                        border.color: deleteMode ? "#d97706" : "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "✂️"
                        font.pixelSize: 14
                        color: "white"
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
                        color: parent.pressed ? "#4a4a4a" : "#3a3a3a"
                        radius: 4
                        border.color: "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "📷"
                        font.pixelSize: 14
                        color: "white"
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
                        color: parent.pressed ? "#4a4a4a" : "#3a3a3a"
                        radius: 4
                        border.color: "#5a5a5a"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "⛶"
                        font.pixelSize: 14
                        color: "white"
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
                        color: parent.pressed ? "#7f1d1d" : "#991b1b"
                        radius: 4
                        border.color: "#dc2626"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: 16
                        color: "white"
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
            color: "#1e1e1e"
            border.color: "#3a3a3a"
            border.width: 1
            visible: true  // Always visible
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15
                
                Text {
                    text: "Status:"
                    color: "#9ca3af"
                    font.pixelSize: 11
                }
                
                Text {
                    text: camera.active ? "Active" : "Inactive"
                    color: camera.active ? "#4ade80" : "#6b7280"
                    font.pixelSize: 11
                    font.bold: true
                }
                
                Text {
                    visible: motionDetectionEnabled && motionDetector.motionLevel > 0
                    text: "• Motion: " + Math.round(motionDetector.motionLevel * 100) + "%"
                    color: motionDetector.motionDetected ? "#ef4444" : "#9ca3af"
                    font.pixelSize: 11
                    font.bold: motionDetector.motionDetected
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
                        color: "#d1d5db"
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
                            color: "#374151"
                        }
                        handle: Rectangle {
                            x: sensitivitySlider.leftPadding + sensitivitySlider.visualPosition * (sensitivitySlider.availableWidth - width)
                            y: sensitivitySlider.topPadding + sensitivitySlider.availableHeight / 2 - height / 2
                            implicitWidth: 18  // Larger handle for easier clicking
                            implicitHeight: 18
                            radius: 9
                            color: sensitivitySlider.pressed ? "#3b82f6" : "#60a5fa"
                            border.color: "#2563eb"
                            border.width: 2
                        }
                        onValueChanged: tile.motionSensitivity = value
                    }
                }
                
                Button {
                    width: 70
                    height: 28
                    background: Rectangle {
                        color: camera.active ? "#dc2626" : "#10b981"
                        radius: 4
                        border.color: camera.active ? "#b91c1c" : "#059669"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: camera.active ? "Stop" : "Start"
                        color: "white"
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
        color: "#1a1a1a"
        visible: !cameraId || cameraId === ""
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No Camera"
                color: "#666666"
                font.pixelSize: 16
            }
            
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Add Camera"
                onClicked: {
                    tile.addCameraRequested(tile.tileIndex)
                }
            }
        }
    }
}

