#ifndef MOTIONDETECTOR_H
#define MOTIONDETECTOR_H

#include <QObject>
#include <QVideoSink>
#include <QVideoFrame>
#include <QImage>
#include <QTimer>
#include <QPointF>

class MotionDetector : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(double sensitivity READ sensitivity WRITE setSensitivity NOTIFY sensitivityChanged)
    Q_PROPERTY(double motionLevel READ motionLevel NOTIFY motionLevelChanged)
    Q_PROPERTY(bool motionDetected READ motionDetected NOTIFY motionDetectedChanged)

public:
    explicit MotionDetector(QObject *parent = nullptr);
    
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    
    double sensitivity() const { return m_sensitivity; }  // 0.0 to 1.0
    void setSensitivity(double sensitivity);
    
    double motionLevel() const { return m_motionLevel; }  // 0.0 to 1.0
    bool motionDetected() const { return m_motionDetected; }
    QPointF motionCentroid() const { return m_motionCentroid; }  // Normalized 0.0-1.0
    
    Q_INVOKABLE void setVideoSink(QVideoSink *sink);

signals:
    void enabledChanged();
    void sensitivityChanged();
    void motionLevelChanged();
    void motionDetectedChanged();
    void motionDetectedSignal(double level);
    void motionCentroidChanged(double x, double y);  // Normalized coordinates 0.0-1.0

private slots:
    void processFrame(const QVideoFrame &frame);

private:
    double calculateMotion(const QImage &current, const QImage &previous);
    QPointF calculateMotionCentroid(const QImage &current, const QImage &previous);
    QImage videoFrameToImage(const QVideoFrame &frame);
    
    QVideoSink *m_videoSink;
    QImage m_previousFrame;
    bool m_enabled;
    double m_sensitivity;  // Threshold for motion detection (0.0-1.0)
    double m_motionLevel;  // Current motion level (0.0-1.0)
    bool m_motionDetected;
    QPointF m_motionCentroid;  // Center of motion (normalized 0.0-1.0)
    QPointF m_previousCentroid;  // Previous centroid for tracking movement
    QTimer *m_cooldownTimer;
    bool m_hasPreviousFrame;
};

#endif // MOTIONDETECTOR_H

