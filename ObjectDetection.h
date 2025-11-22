#ifndef OBJECTDETECTION_H
#define OBJECTDETECTION_H

#include <opencv2/opencv.hpp>
#include <opencv2/dnn.hpp>
#include <QObject>

class ObjectDetection : public QObject {
    Q_OBJECT
public:
    explicit ObjectDetection(QObject *parent = nullptr);
    bool loadModel(const std::string &modelPath);
    void processFrame(const cv::Mat &frame);

signals:
    void detectionsReady(const QList<QRect> &boxes, const QList<int> &classIds);

private:
    cv::dnn::Net net;
};

#endif // OBJECTDETECTION_H