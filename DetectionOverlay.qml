import QtQuick

Canvas {
    id: overlay

    property var detections: []
    property color boxColor: "#52c9a2"

    onDetectionsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var context = getContext("2d")
        context.reset()
        context.lineWidth = 2
        context.font = "bold 12px sans-serif"

        for (var i = 0; i < detections.length; ++i) {
            var detection = detections[i]
            var x = detection.x * width
            var y = detection.y * height
            var boxWidth = detection.width * width
            var boxHeight = detection.height * height
            var caption = detection.label + " " + Math.round(detection.confidence * 100) + "%"

            context.strokeStyle = boxColor
            context.strokeRect(x, y, boxWidth, boxHeight)

            var captionWidth = context.measureText(caption).width + 12
            var captionY = Math.max(0, y - 22)
            context.fillStyle = boxColor
            context.fillRect(x, captionY, captionWidth, 22)
            context.fillStyle = "#0f1720"
            context.fillText(caption, x + 6, captionY + 15)
        }
    }
}
