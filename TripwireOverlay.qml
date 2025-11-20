import QtQuick
import QtQuick.Shapes

Item {
    id: overlay
    property var tripwireManager: null
    property string tileId: ""  // Changed from cameraId to tileId for tile-specific tripwires
    property bool drawingMode: false
    property string drawingType: "tripwire"  // "tripwire" or "roi"
    property bool deleteMode: false  // Enable delete mode to remove tripwires/ROIs
    
    // Drawing state
    property var currentPoints: []
    property var startPoint: null
    property var currentMousePoint: null
    
    // Canvas for drawing ROIs and tripwires
    Canvas {
        id: canvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            // Draw tripwires (filtered by tileId)
            if (tripwireManager && tileId) {
                var tripwires = tripwireManager.getAllTripwires(tileId)
                for (var i = 0; i < tripwires.length; i++) {
                    var tw = tripwires[i]
                    if (tw.enabled) {
                        ctx.strokeStyle = "#00ff00"
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.moveTo(tw.startX * width, tw.startY * height)
                        ctx.lineTo(tw.endX * width, tw.endY * height)
                        ctx.stroke()
                    }
                }
                
                // Draw ROIs (filtered by tileId)
                var rois = tripwireManager.getAllROIs(tileId)
                for (var j = 0; j < rois.length; j++) {
                    var roi = rois[j]
                    if (roi.enabled && roi.points && roi.points.length > 0) {
                        ctx.strokeStyle = "#ff6600"
                        ctx.fillStyle = "#33ff6600"
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.moveTo(roi.points[0].x * width, roi.points[0].y * height)
                        for (var k = 1; k < roi.points.length; k++) {
                            ctx.lineTo(roi.points[k].x * width, roi.points[k].y * height)
                        }
                        ctx.closePath()
                        ctx.fill()
                        ctx.stroke()
                    }
                }
            }
            
            // Draw current drawing
            if (drawingMode && startPoint !== null) {
                if (drawingType === "tripwire") {
                    ctx.strokeStyle = "#00ff00"
                    ctx.lineWidth = 2
                    ctx.setLineDash([5, 5])
                    ctx.beginPath()
                    ctx.moveTo(startPoint.x, startPoint.y)
                    if (currentMousePoint) {
                        ctx.lineTo(currentMousePoint.x, currentMousePoint.y)
                    }
                    ctx.stroke()
                    ctx.setLineDash([])
                } else if (drawingType === "roi" && currentPoints.length > 0) {
                    ctx.strokeStyle = "#ff6600"
                    ctx.fillStyle = "#33ff6600"
                    ctx.lineWidth = 2
                    ctx.setLineDash([5, 5])
                    ctx.beginPath()
                    ctx.moveTo(startPoint.x, startPoint.y)
                    for (var p = 0; p < currentPoints.length; p++) {
                        ctx.lineTo(currentPoints[p].x, currentPoints[p].y)
                    }
                    if (currentMousePoint) {
                        ctx.lineTo(currentMousePoint.x, currentMousePoint.y)
                    }
                    ctx.closePath()
                    ctx.fill()
                    ctx.stroke()
                    ctx.setLineDash([])
                }
            }
        }
    }
    
    // Update canvas when tripwires/ROIs change
    Connections {
        target: tripwireManager
        function onTripwiresChanged() {
            canvas.requestPaint()
        }
        function onRoisChanged() {
            canvas.requestPaint()
        }
    }
    
    onStartPointChanged: canvas.requestPaint()
    onCurrentPointsChanged: canvas.requestPaint()
    onCurrentMousePointChanged: canvas.requestPaint()
    
    // Reset drawing state when drawing mode or delete mode changes
    onDrawingModeChanged: {
        canvas.requestPaint()
        if (!drawingMode) {
            startPoint = null
            currentPoints = []
            currentMousePoint = null
        }
    }
    
    onDeleteModeChanged: {
        canvas.requestPaint()
    }
    
    // Mouse area for drawing
    MouseArea {
        id: drawingArea
        anchors.fill: parent
        enabled: drawingMode || deleteMode
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 10  // Below other UI elements
        propagateComposedEvents: false  // Don't propagate to prevent flickering
        
        onPressed: function(mouse) {
            // Exclude the top bar area (top 45px) to prevent interference with buttons
            // Buttons are now outside the video area, so we can draw at the top of the video
            if (mouse.y < 45) {
                mouse.accepted = false  // Let the event pass through to buttons
                return
            }
            
            // Delete mode: right-click or click on existing tripwire/ROI to delete
            if (deleteMode || mouse.button === Qt.RightButton) {
                if (tripwireManager && tileId) {
                    var tripwires = tripwireManager.getAllTripwires(tileId)
                    var rois = tripwireManager.getAllROIs(tileId)
                    
                    // Check if click is near a tripwire
                    var clickX = mouse.x / overlay.width
                    var clickY = mouse.y / overlay.height
                    var threshold = 0.02  // 2% of screen size
                    
                    for (var i = 0; i < tripwires.length; i++) {
                        var tw = tripwires[i]
                        if (tw.enabled) {
                            // Calculate distance from point to line
                            var dx = tw.endX - tw.startX
                            var dy = tw.endY - tw.startY
                            var length = Math.sqrt(dx * dx + dy * dy)
                            if (length > 0) {
                                var t = Math.max(0, Math.min(1, ((clickX - tw.startX) * dx + (clickY - tw.startY) * dy) / (length * length)))
                                var projX = tw.startX + t * dx
                                var projY = tw.startY + t * dy
                                var dist = Math.sqrt((clickX - projX) * (clickX - projX) + (clickY - projY) * (clickY - projY))
                                if (dist < threshold) {
                                    tripwireManager.removeTripwire(tw.id)
                                    canvas.requestPaint()
                                    return
                                }
                            }
                        }
                    }
                    
                    // Check if click is inside an ROI
                    for (var j = 0; j < rois.length; j++) {
                        var roi = rois[j]
                        if (roi.enabled && roi.points && roi.points.length > 0) {
                            // Simple point-in-polygon check
                            var inside = false
                            for (var k = 0, l = roi.points.length - 1; k < roi.points.length; l = k++) {
                                var xi = roi.points[k].x
                                var yi = roi.points[k].y
                                var xj = roi.points[l].x
                                var yj = roi.points[l].y
                                var intersect = ((yi > clickY) !== (yj > clickY)) && 
                                                (clickX < (xj - xi) * (clickY - yi) / (yj - yi) + xi)
                                if (intersect) inside = !inside
                            }
                            if (inside) {
                                tripwireManager.removeROI(roi.id)
                                canvas.requestPaint()
                                return
                            }
                        }
                    }
                }
                return
            }
            
            if (drawingType === "tripwire") {
                if (startPoint === null) {
                    startPoint = Qt.point(mouse.x, mouse.y)
                    currentPoints = []
                } else {
                    // Complete tripwire
                    var endPoint = Qt.point(mouse.x, mouse.y)
                    var startNorm = Qt.point(startPoint.x / overlay.width, startPoint.y / overlay.height)
                    var endNorm = Qt.point(endPoint.x / overlay.width, endPoint.y / overlay.height)
                    if (tripwireManager && tileId) {
                        tripwireManager.addTripwire(tileId, startNorm, endNorm)
                    }
                    startPoint = null
                    currentPoints = []
                    currentMousePoint = null
                }
            } else if (drawingType === "roi") {
                if (startPoint === null) {
                    startPoint = Qt.point(mouse.x, mouse.y)
                    currentPoints = [Qt.point(mouse.x, mouse.y)]
                } else {
                    // Add point to polygon
                    currentPoints.push(Qt.point(mouse.x, mouse.y))
                    canvas.requestPaint()
                }
            }
        }
        
        onPositionChanged: function(mouse) {
            if (drawingMode && startPoint !== null) {
                currentMousePoint = Qt.point(mouse.x, mouse.y)
                canvas.requestPaint()
            }
        }
        
        onDoubleClicked: function(mouse) {
            if (drawingType === "roi" && startPoint !== null && currentPoints.length >= 2) {
                // Complete ROI polygon - convert to QVariantList format
                var polygon = []
                polygon.push({"x": startPoint.x / overlay.width, "y": startPoint.y / overlay.height})
                for (var i = 1; i < currentPoints.length; i++) {
                    polygon.push({"x": currentPoints[i].x / overlay.width, 
                                 "y": currentPoints[i].y / overlay.height})
                }
                if (tripwireManager && tileId) {
                    tripwireManager.addROI(tileId, polygon)
                }
                startPoint = null
                currentPoints = []
                currentMousePoint = null
            }
        }
    }
}
