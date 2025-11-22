import QtQuick
import QtQuick.Controls
import QtMultimedia

Window {
    id: fullScreenWindow
    property string cameraId: ""
    property string cameraName: "Camera"
    
    flags: Qt.Window | Qt.FramelessWindowHint
    visibility: Window.FullScreen
    color: "black"
    width: Screen.width
    height: Screen.height
    
    // Root item to handle focus and keys
    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: {
            fullScreenWindow.close()
        }
        
        // MediaDevices to access camera list
        MediaDevices {
            id: mediaDevices
        }
        
        // Camera component
        Camera {
            id: camera
            active: cameraPermissionHelper.hasPermission && cameraId !== ""
            
            function updateCameraDevice() {
                if (!cameraId || cameraId === "") {
                    camera.cameraDevice = null
                    return
                }
                
                var devices = mediaDevices.videoInputs
                for (var i = 0; i < devices.length; i++) {
                    var device = devices[i]
                    var deviceId = String(device.id)
                    
                    if (deviceId === cameraId || deviceId.trim() === cameraId.trim()) {
                        camera.cameraDevice = device
                        return
                    }
                }
            }
        }
        
        Component.onCompleted: {
            if (cameraId && cameraId !== "") {
                camera.updateCameraDevice()
            }
        }
        
        // Capture session
        CaptureSession {
            id: captureSession
            camera: camera
            videoOutput: videoOutput
        }
        
        // Video output
        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }
        
        // Top bar with controls
        Rectangle {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "#80000000"
            visible: controlMouseArea.containsMouse
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15
                
                Text {
                    text: cameraName
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                Text {
                    text: camera.active ? "● Active" : "○ Inactive"
                    color: camera.active ? "lightgreen" : "gray"
                    font.pixelSize: 14
                }
            }
            
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                
                Button {
                    text: camera.active ? "Stop" : "Start"
                    onClicked: camera.active = !camera.active
                }
                
                Button {
                    text: "Exit Full Screen"
                    onClicked: fullScreenWindow.close()
                }
            }
        }
        
        // Mouse area for hover detection
        MouseArea {
            id: controlMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onClicked: rootItem.focus = true  // Regain focus on click
        }
    }
}
