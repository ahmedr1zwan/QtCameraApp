#ifndef ANALYTICSENGINE_H
#define ANALYTICSENGINE_H

#include <QElapsedTimer>
#include <QHash>
#include <QImage>
#include <QObject>
#include <QPointF>
#include <QStringList>
#include <QVariantList>
#include <QVideoFrame>
#include <QVideoSink>

#include <opencv2/core.hpp>
#include <opencv2/dnn.hpp>
#include <opencv2/video/background_segm.hpp>

class AnalyticsEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool motionEnabled READ motionEnabled WRITE setMotionEnabled NOTIFY motionEnabledChanged)
    Q_PROPERTY(bool objectDetectionEnabled READ objectDetectionEnabled WRITE setObjectDetectionEnabled NOTIFY objectDetectionEnabledChanged)
    Q_PROPERTY(double sensitivity READ sensitivity WRITE setSensitivity NOTIFY sensitivityChanged)
    Q_PROPERTY(double confidenceThreshold READ confidenceThreshold WRITE setConfidenceThreshold NOTIFY confidenceThresholdChanged)
    Q_PROPERTY(double motionLevel READ motionLevel NOTIFY motionLevelChanged)
    Q_PROPERTY(bool motionDetected READ motionDetected NOTIFY motionDetectedChanged)
    Q_PROPERTY(QPointF motionCentroid READ motionCentroid NOTIFY motionCentroidChanged)
    Q_PROPERTY(int framesPerSecond READ framesPerSecond NOTIFY framesPerSecondChanged)
    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(QString labelsPath READ labelsPath WRITE setLabelsPath NOTIFY labelsPathChanged)
    Q_PROPERTY(QString modelStatus READ modelStatus NOTIFY modelStatusChanged)
    Q_PROPERTY(bool modelReady READ modelReady NOTIFY modelStatusChanged)
    Q_PROPERTY(QVariantList detections READ detections NOTIFY detectionsChanged)

public:
    explicit AnalyticsEngine(QObject *parent = nullptr);

    bool motionEnabled() const { return m_motionEnabled; }
    void setMotionEnabled(bool enabled);
    bool objectDetectionEnabled() const { return m_objectDetectionEnabled; }
    void setObjectDetectionEnabled(bool enabled);

    double sensitivity() const { return m_sensitivity; }
    void setSensitivity(double sensitivity);
    double confidenceThreshold() const { return m_confidenceThreshold; }
    void setConfidenceThreshold(double threshold);

    double motionLevel() const { return m_motionLevel; }
    bool motionDetected() const { return m_motionDetected; }
    QPointF motionCentroid() const { return m_motionCentroid; }
    int framesPerSecond() const { return m_framesPerSecond; }

    QString modelPath() const { return m_modelPath; }
    void setModelPath(const QString &path);
    QString labelsPath() const { return m_labelsPath; }
    void setLabelsPath(const QString &path);
    QString modelStatus() const { return m_modelStatus; }
    bool modelReady() const { return !m_network.empty(); }
    QVariantList detections() const { return m_detections; }

    Q_INVOKABLE void setVideoSink(QVideoSink *sink);

signals:
    void motionEnabledChanged();
    void objectDetectionEnabledChanged();
    void sensitivityChanged();
    void confidenceThresholdChanged();
    void motionLevelChanged();
    void motionDetectedChanged();
    void motionDetectedSignal(double level);
    void motionCentroidChanged(double x, double y);
    void framesPerSecondChanged();
    void modelPathChanged();
    void labelsPathChanged();
    void modelStatusChanged();
    void detectionsChanged();
    void objectDetected(const QString &label, double confidence, double centerX, double centerY);

private slots:
    void processFrame(const QVideoFrame &frame);

private:
    struct Candidate {
        int classId = -1;
        float confidence = 0.0F;
        cv::Rect box;
    };

    static QString localPath(const QString &path);
    static QImage frameToImage(const QVideoFrame &frame);
    void resetMotionState();
    void processMotion(const cv::Mat &bgrFrame);
    void runObjectDetection(const cv::Mat &bgrFrame);
    QList<Candidate> decodeOutput(const cv::Mat &output, const cv::Size &frameSize) const;
    void loadModel();
    void loadLabels();
    void setModelStatus(const QString &status);
    QString labelForClass(int classId) const;

    QVideoSink *m_videoSink = nullptr;
    bool m_motionEnabled = false;
    bool m_objectDetectionEnabled = false;
    double m_sensitivity = 0.55;
    double m_confidenceThreshold = 0.45;
    double m_motionLevel = 0.0;
    bool m_motionDetected = false;
    QPointF m_motionCentroid{-1.0, -1.0};
    QString m_modelPath;
    QString m_labelsPath;
    QString m_modelStatus = QStringLiteral("Select a YOLO ONNX model");
    QStringList m_labels;
    QVariantList m_detections;
    cv::dnn::Net m_network;
    cv::Ptr<cv::BackgroundSubtractor> m_backgroundSubtractor;
    int m_motionWarmupFrames = 0;
    int m_frameCount = 0;
    int m_framesPerSecond = 0;
    QElapsedTimer m_frameClock;
    QElapsedTimer m_inferenceClock;
    QElapsedTimer m_motionAlertClock;
    QHash<QString, qint64> m_lastObjectAlert;
};

#endif // ANALYTICSENGINE_H
