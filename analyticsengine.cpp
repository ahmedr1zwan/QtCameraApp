#include "analyticsengine.h"

#include <QFile>
#include <QFileInfo>
#include <QDateTime>
#include <QTextStream>
#include <QUrl>

#include <algorithm>
#include <cmath>
#include <vector>

#include <opencv2/imgproc.hpp>

namespace {
constexpr int kMotionWidth = 320;
constexpr int kInputSize = 640;
constexpr int kInferenceIntervalMs = 200;
constexpr int kAlertCooldownMs = 2000;

double motionThreshold(double sensitivity)
{
    // Higher sensitivity lowers the foreground-area threshold.
    return 0.12 - (std::clamp(sensitivity, 0.0, 1.0) * 0.115);
}
}

AnalyticsEngine::AnalyticsEngine(QObject *parent)
    : QObject(parent)
    , m_backgroundSubtractor(cv::createBackgroundSubtractorMOG2(300, 24.0, true))
{
    m_inferenceClock.start();
    m_motionAlertClock.start();
    m_frameClock.start();
}

void AnalyticsEngine::setMotionEnabled(bool enabled)
{
    if (m_motionEnabled == enabled)
        return;
    m_motionEnabled = enabled;
    resetMotionState();
    emit motionEnabledChanged();
}

void AnalyticsEngine::setObjectDetectionEnabled(bool enabled)
{
    if (m_objectDetectionEnabled == enabled)
        return;
    m_objectDetectionEnabled = enabled;
    if (!enabled && !m_detections.isEmpty()) {
        m_detections.clear();
        emit detectionsChanged();
    }
    emit objectDetectionEnabledChanged();
}

void AnalyticsEngine::setSensitivity(double sensitivity)
{
    sensitivity = std::clamp(sensitivity, 0.0, 1.0);
    if (qFuzzyCompare(m_sensitivity, sensitivity))
        return;
    m_sensitivity = sensitivity;
    emit sensitivityChanged();
}

void AnalyticsEngine::setConfidenceThreshold(double threshold)
{
    threshold = std::clamp(threshold, 0.05, 0.95);
    if (qFuzzyCompare(m_confidenceThreshold, threshold))
        return;
    m_confidenceThreshold = threshold;
    emit confidenceThresholdChanged();
}

void AnalyticsEngine::setModelPath(const QString &path)
{
    const QString resolved = localPath(path);
    if (m_modelPath == resolved)
        return;
    m_modelPath = resolved;
    emit modelPathChanged();
    loadModel();
}

void AnalyticsEngine::setLabelsPath(const QString &path)
{
    const QString resolved = localPath(path);
    if (m_labelsPath == resolved)
        return;
    m_labelsPath = resolved;
    emit labelsPathChanged();
    loadLabels();
}

void AnalyticsEngine::setVideoSink(QVideoSink *sink)
{
    if (m_videoSink == sink)
        return;
    if (m_videoSink)
        disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &AnalyticsEngine::processFrame);
    m_videoSink = sink;
    if (m_videoSink) {
        connect(m_videoSink, &QVideoSink::videoFrameChanged,
                this, &AnalyticsEngine::processFrame, Qt::QueuedConnection);
    }
    m_frameCount = 0;
    m_framesPerSecond = 0;
    m_frameClock.restart();
    emit framesPerSecondChanged();
    resetMotionState();
}

QString AnalyticsEngine::localPath(const QString &path)
{
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

QImage AnalyticsEngine::frameToImage(const QVideoFrame &frame)
{
    if (!frame.isValid())
        return {};
    QVideoFrame copy(frame);
    const QImage image = copy.toImage();
    return image.isNull() ? QImage{} : image.convertToFormat(QImage::Format_RGB888);
}

void AnalyticsEngine::processFrame(const QVideoFrame &frame)
{
    ++m_frameCount;
    const qint64 frameWindow = m_frameClock.elapsed();
    if (frameWindow >= 1000) {
        const int measuredFps = qRound((m_frameCount * 1000.0) / frameWindow);
        m_frameCount = 0;
        m_frameClock.restart();
        if (m_framesPerSecond != measuredFps) {
            m_framesPerSecond = measuredFps;
            emit framesPerSecondChanged();
        }
    }

    if (!m_motionEnabled && !m_objectDetectionEnabled)
        return;

    const QImage image = frameToImage(frame);
    if (image.isNull())
        return;

    const cv::Mat rgb(image.height(), image.width(), CV_8UC3,
                      const_cast<uchar *>(image.constBits()), image.bytesPerLine());
    cv::Mat bgr;
    cv::cvtColor(rgb, bgr, cv::COLOR_RGB2BGR);

    if (m_motionEnabled)
        processMotion(bgr);
    if (m_objectDetectionEnabled && modelReady()
        && m_inferenceClock.elapsed() >= kInferenceIntervalMs) {
        m_inferenceClock.restart();
        runObjectDetection(bgr);
    }
}

void AnalyticsEngine::resetMotionState()
{
    m_backgroundSubtractor = cv::createBackgroundSubtractorMOG2(300, 24.0, true);
    m_motionWarmupFrames = 0;
    m_motionLevel = 0.0;
    m_motionDetected = false;
    m_motionCentroid = {-1.0, -1.0};
    emit motionLevelChanged();
    emit motionDetectedChanged();
    emit motionCentroidChanged(-1.0, -1.0);
}

void AnalyticsEngine::processMotion(const cv::Mat &bgrFrame)
{
    const int targetHeight = std::max(1, bgrFrame.rows * kMotionWidth / bgrFrame.cols);
    cv::Mat resized;
    cv::resize(bgrFrame, resized, {kMotionWidth, targetHeight}, 0, 0, cv::INTER_AREA);
    cv::GaussianBlur(resized, resized, {5, 5}, 0);

    cv::Mat mask;
    m_backgroundSubtractor->apply(resized, mask);
    cv::threshold(mask, mask, 200, 255, cv::THRESH_BINARY);
    const cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, {5, 5});
    cv::morphologyEx(mask, mask, cv::MORPH_OPEN, kernel);
    cv::dilate(mask, mask, kernel, {-1, -1}, 2);

    const double level = static_cast<double>(cv::countNonZero(mask))
                         / static_cast<double>(mask.rows * mask.cols);
    if (!qFuzzyCompare(m_motionLevel, level)) {
        m_motionLevel = level;
        emit motionLevelChanged();
    }

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    double weightedX = 0.0;
    double weightedY = 0.0;
    double totalArea = 0.0;
    for (const auto &contour : contours) {
        const double area = cv::contourArea(contour);
        if (area < 80.0)
            continue;
        const cv::Moments moments = cv::moments(contour);
        if (moments.m00 <= 0.0)
            continue;
        weightedX += (moments.m10 / moments.m00) * area;
        weightedY += (moments.m01 / moments.m00) * area;
        totalArea += area;
    }

    if (totalArea > 0.0) {
        const QPointF centroid((weightedX / totalArea) / mask.cols,
                               (weightedY / totalArea) / mask.rows);
        m_motionCentroid = centroid;
        emit motionCentroidChanged(centroid.x(), centroid.y());
    }

    ++m_motionWarmupFrames;
    const bool detected = m_motionWarmupFrames > 12 && level >= motionThreshold(m_sensitivity);
    if (m_motionDetected != detected) {
        m_motionDetected = detected;
        emit motionDetectedChanged();
    }
    if (detected && m_motionAlertClock.elapsed() >= kAlertCooldownMs) {
        m_motionAlertClock.restart();
        emit motionDetectedSignal(level);
    }
}

void AnalyticsEngine::runObjectDetection(const cv::Mat &bgrFrame)
{
    try {
        const cv::Mat blob = cv::dnn::blobFromImage(
            bgrFrame, 1.0 / 255.0, {kInputSize, kInputSize}, {}, true, false);
        m_network.setInput(blob);
        std::vector<cv::Mat> outputs;
        m_network.forward(outputs, m_network.getUnconnectedOutLayersNames());
        if (outputs.empty())
            return;

        const QList<Candidate> candidates = decodeOutput(outputs.front(), bgrFrame.size());
        QVariantList detections;
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        for (const Candidate &candidate : candidates) {
            const QRectF normalized(
                static_cast<double>(candidate.box.x) / bgrFrame.cols,
                static_cast<double>(candidate.box.y) / bgrFrame.rows,
                static_cast<double>(candidate.box.width) / bgrFrame.cols,
                static_cast<double>(candidate.box.height) / bgrFrame.rows);
            const QPointF center = normalized.center();
            const QString label = labelForClass(candidate.classId);
            detections.append(QVariantMap{
                {QStringLiteral("label"), label},
                {QStringLiteral("classId"), candidate.classId},
                {QStringLiteral("confidence"), candidate.confidence},
                {QStringLiteral("x"), normalized.x()},
                {QStringLiteral("y"), normalized.y()},
                {QStringLiteral("width"), normalized.width()},
                {QStringLiteral("height"), normalized.height()},
                {QStringLiteral("centerX"), center.x()},
                {QStringLiteral("centerY"), center.y()}
            });
            if (now - m_lastObjectAlert.value(label, 0) >= kAlertCooldownMs) {
                m_lastObjectAlert[label] = now;
                emit objectDetected(label, candidate.confidence, center.x(), center.y());
            }
        }
        m_detections = detections;
        emit detectionsChanged();
    } catch (const cv::Exception &error) {
        setModelStatus(QStringLiteral("Inference error: %1").arg(QString::fromUtf8(error.what())));
        m_objectDetectionEnabled = false;
        emit objectDetectionEnabledChanged();
    }
}

QList<AnalyticsEngine::Candidate> AnalyticsEngine::decodeOutput(
    const cv::Mat &output, const cv::Size &frameSize) const
{
    cv::Mat rows;
    if (output.dims == 3 && output.size[1] < output.size[2] && output.size[1] <= 256) {
        const cv::Mat channels(output.size[1], output.size[2], CV_32F,
                               const_cast<float *>(output.ptr<float>()));
        cv::transpose(channels, rows); // YOLOv8: [1, attributes, predictions]
    } else if (output.dims == 3) {
        rows = output.reshape(1, output.size[1]); // YOLOv5: [1, predictions, attributes]
    } else if (output.dims == 2) {
        rows = output;
    } else {
        return {};
    }

    const bool hasObjectness = rows.cols >= 6
                               && (m_labels.isEmpty() || rows.cols == m_labels.size() + 5);
    const int classOffset = hasObjectness ? 5 : 4;
    if (rows.cols <= classOffset)
        return {};

    std::vector<cv::Rect> boxes;
    std::vector<float> scores;
    std::vector<int> classIds;
    for (int rowIndex = 0; rowIndex < rows.rows; ++rowIndex) {
        const float *data = rows.ptr<float>(rowIndex);
        const float objectness = hasObjectness ? data[4] : 1.0F;
        if (objectness < static_cast<float>(m_confidenceThreshold))
            continue;

        const cv::Mat classScores(1, rows.cols - classOffset, CV_32F,
                                  const_cast<float *>(data + classOffset));
        cv::Point classPoint;
        double classScore = 0.0;
        cv::minMaxLoc(classScores, nullptr, &classScore, nullptr, &classPoint);
        const float confidence = objectness * static_cast<float>(classScore);
        if (confidence < static_cast<float>(m_confidenceThreshold))
            continue;

        const float scaleX = static_cast<float>(frameSize.width) / kInputSize;
        const float scaleY = static_cast<float>(frameSize.height) / kInputSize;
        const float width = data[2] * scaleX;
        const float height = data[3] * scaleY;
        const int left = std::max(0, static_cast<int>((data[0] * scaleX) - width / 2.0F));
        const int top = std::max(0, static_cast<int>((data[1] * scaleY) - height / 2.0F));
        cv::Rect box(left, top, static_cast<int>(width), static_cast<int>(height));
        box &= cv::Rect(0, 0, frameSize.width, frameSize.height);
        if (box.empty())
            continue;
        boxes.push_back(box);
        scores.push_back(confidence);
        classIds.push_back(classPoint.x);
    }

    std::vector<int> kept;
    cv::dnn::NMSBoxes(boxes, scores, static_cast<float>(m_confidenceThreshold), 0.45F, kept);
    QList<Candidate> result;
    for (const int index : kept)
        result.append(Candidate{classIds[index], scores[index], boxes[index]});
    return result;
}

void AnalyticsEngine::loadModel()
{
    m_network = {};
    if (m_modelPath.isEmpty()) {
        setModelStatus(QStringLiteral("Select a YOLO ONNX model"));
        return;
    }
    if (!QFileInfo::exists(m_modelPath)) {
        setModelStatus(QStringLiteral("Model file not found"));
        return;
    }
    try {
        m_network = cv::dnn::readNetFromONNX(m_modelPath.toStdString());
        m_network.setPreferableBackend(cv::dnn::DNN_BACKEND_OPENCV);
        m_network.setPreferableTarget(cv::dnn::DNN_TARGET_CPU);
        setModelStatus(QStringLiteral("YOLO ready (OpenCV DNN / CPU)"));
    } catch (const cv::Exception &error) {
        m_network = {};
        setModelStatus(QStringLiteral("Model load failed: %1").arg(QString::fromUtf8(error.what())));
    }
}

void AnalyticsEngine::loadLabels()
{
    m_labels.clear();
    QFile file(m_labelsPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        while (!stream.atEnd()) {
            const QString label = stream.readLine().trimmed();
            if (!label.isEmpty())
                m_labels.append(label);
        }
    }
}

void AnalyticsEngine::setModelStatus(const QString &status)
{
    if (m_modelStatus == status)
        return;
    m_modelStatus = status;
    emit modelStatusChanged();
}

QString AnalyticsEngine::labelForClass(int classId) const
{
    if (classId >= 0 && classId < m_labels.size())
        return m_labels.at(classId);
    return QStringLiteral("class_%1").arg(classId);
}
