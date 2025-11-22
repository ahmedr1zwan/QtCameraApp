#include "ObjectDetection.h"

ObjectDetection::ObjectDetection(QObject *parent) : QObject(parent) {}

bool ObjectDetection::loadModel(const std::string &modelPath) {
    net = cv::dnn::readNetFromONNX(modelPath);
    return !net.empty();
}

void ObjectDetection::processFrame(const cv::Mat &frame) {
    cv::Mat blob;
    cv::dnn::blobFromImage(frame, blob, 1/255.0, cv::Size(640, 640), cv::Scalar(0, 0, 0), true, false);
    net.setInput(blob);
    cv::Mat detections = net.forward();

    QList<QRect> boxes;
    QList<int> classIds;

    for (int i = 0; i < detections.rows; i++) {
        float confidence = detections.at<float>(i, 4);
        if (confidence > 0.5) { // Confidence threshold
            int classId = static_cast<int>(detections.at<float>(i, 5));
            int x = static_cast<int>(detections.at<float>(i, 0) * frame.cols);
            int y = static_cast<int>(detections.at<float>(i, 1) * frame.rows);
            int width = static_cast<int>(detections.at<float>(i, 2) * frame.cols);
            int height = static_cast<int>(detections.at<float>(i, 3) * frame.rows);
            boxes.append(QRect(x, y, width, height));
            classIds.append(classId);
        }
    }

    emit detectionsReady(boxes, classIds);
}