#include "motiondetector.h"
#include <QDebug>
#include <QVideoFrame>
#include <QVideoSink>

MotionDetector::MotionDetector(QObject *parent)
    : QObject(parent)
    , m_videoSink(nullptr)
    , m_enabled(false)
    , m_sensitivity(0.3)  // Default 30% threshold
    , m_motionLevel(0.0)
    , m_motionDetected(false)
    , m_hasPreviousFrame(false)
    , m_motionCentroid(-1.0, -1.0)  // Use (-1, -1) as sentinel for "no motion" to avoid conflict with top-left corner (0, 0)
    , m_previousCentroid(-1.0, -1.0)
{
    m_cooldownTimer = new QTimer(this);
    m_cooldownTimer->setSingleShot(true);
    m_cooldownTimer->setInterval(1000);  // 1 second cooldown between detections
}

void MotionDetector::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_hasPreviousFrame = false;
        m_motionLevel = 0.0;
        m_motionDetected = false;
        emit enabledChanged();
        emit motionLevelChanged();
        emit motionDetectedChanged();
    }
}

void MotionDetector::setSensitivity(double sensitivity)
{
    if (m_sensitivity != sensitivity) {
        m_sensitivity = qBound(0.0, sensitivity, 1.0);
        emit sensitivityChanged();
    }
}

void MotionDetector::setVideoSink(QVideoSink *sink)
{
    if (m_videoSink == sink)
        return;
    
    if (m_videoSink) {
        disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &MotionDetector::processFrame);
    }
    
    m_videoSink = sink;
    
    if (m_videoSink) {
        connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &MotionDetector::processFrame);
    }
    
    m_hasPreviousFrame = false;
}

void MotionDetector::processFrame(const QVideoFrame &frame)
{
    if (!m_enabled || !m_videoSink)
        return;
    
    QImage currentImage = videoFrameToImage(frame);
    if (currentImage.isNull())
        return;
    
    if (!m_hasPreviousFrame) {
        m_previousFrame = currentImage;
        m_hasPreviousFrame = true;
        return;
    }
    
    // Calculate motion level and centroid
    double motion = calculateMotion(currentImage, m_previousFrame);
    QPointF centroid = calculateMotionCentroid(currentImage, m_previousFrame);
    
    // Update motion level
    if (m_motionLevel != motion) {
        m_motionLevel = motion;
        emit motionLevelChanged();
    }
    
    // Always emit centroid when there's motion (even if below threshold)
    // This allows tripwire/ROI detection to work even with slow movements
    // Use (-1, -1) as sentinel for "no motion" to avoid conflict with top-left corner (0, 0)
    if (motion > 0.01 && centroid != QPointF(-1, -1)) {  // Any motion above 1%
        m_previousCentroid = m_motionCentroid;
        m_motionCentroid = centroid;
        emit motionCentroidChanged(centroid.x(), centroid.y());
    }
    
    // Check if motion exceeds threshold
    bool detected = (motion >= m_sensitivity);
    
    if (detected && !m_motionDetected && !m_cooldownTimer->isActive()) {
        m_motionDetected = true;
        emit motionDetectedChanged();
        emit motionDetectedSignal(motion);
        m_cooldownTimer->start();
    } else if (!detected && m_motionDetected) {
        m_motionDetected = false;
        emit motionDetectedChanged();
    }
    
    // Update previous frame
    m_previousFrame = currentImage;
}

double MotionDetector::calculateMotion(const QImage &current, const QImage &previous)
{
    if (current.size() != previous.size())
        return 0.0;
    
    // Resize images to smaller size for faster processing
    QSize smallSize(160, 120);  // Process at lower resolution for performance
    QImage currentSmall = current.scaled(smallSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    QImage previousSmall = previous.scaled(smallSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    
    int width = currentSmall.width();
    int height = currentSmall.height();
    int totalPixels = width * height;
    int changedPixels = 0;
    
    // Compare pixels (simple difference method)
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            QRgb currentPixel = currentSmall.pixel(x, y);
            QRgb previousPixel = previousSmall.pixel(x, y);
            
            // Calculate color difference
            int rDiff = qAbs(qRed(currentPixel) - qRed(previousPixel));
            int gDiff = qAbs(qGreen(currentPixel) - qGreen(previousPixel));
            int bDiff = qAbs(qBlue(currentPixel) - qBlue(previousPixel));
            
            int totalDiff = rDiff + gDiff + bDiff;
            
            // Consider pixel changed if difference exceeds threshold (30 out of 765 max)
            if (totalDiff > 30) {
                changedPixels++;
            }
        }
    }
    
    // Return motion level as percentage
    return static_cast<double>(changedPixels) / totalPixels;
}

QPointF MotionDetector::calculateMotionCentroid(const QImage &current, const QImage &previous)
{
    if (current.size() != previous.size())
        return QPointF(-1, -1);  // Use (-1, -1) as sentinel for "no motion"
    
    // Resize images to smaller size for faster processing
    QSize smallSize(160, 120);
    QImage currentSmall = current.scaled(smallSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    QImage previousSmall = previous.scaled(smallSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    
    int width = currentSmall.width();
    int height = currentSmall.height();
    
    double sumX = 0.0;
    double sumY = 0.0;
    int changedPixels = 0;
    
    // Calculate centroid of changed pixels
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            QRgb currentPixel = currentSmall.pixel(x, y);
            QRgb previousPixel = previousSmall.pixel(x, y);
            
            int rDiff = qAbs(qRed(currentPixel) - qRed(previousPixel));
            int gDiff = qAbs(qGreen(currentPixel) - qGreen(previousPixel));
            int bDiff = qAbs(qBlue(currentPixel) - qBlue(previousPixel));
            int totalDiff = rDiff + gDiff + bDiff;
            
            if (totalDiff > 30) {
                sumX += x;
                sumY += y;
                changedPixels++;
            }
        }
    }
    
    if (changedPixels == 0)
        return QPointF(-1, -1);  // Use (-1, -1) as sentinel for "no motion"
    
    // Calculate centroid and normalize to 0.0-1.0
    double centroidX = (sumX / changedPixels) / width;
    double centroidY = (sumY / changedPixels) / height;
    
    return QPointF(centroidX, centroidY);
}

QImage MotionDetector::videoFrameToImage(const QVideoFrame &frame)
{
    if (!frame.isValid())
        return QImage();
    
    QVideoFrame frameCopy = frame;
    if (!frameCopy.map(QVideoFrame::ReadOnly))
        return QImage();
    
    QImage image = frameCopy.toImage();
    frameCopy.unmap();
    
    return image;
}

