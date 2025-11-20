#include "tripwiremanager.h"
#include <QDebug>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <QLineF>
#include <QtMath>
#include <utility>  // For std::as_const
#include <QDateTime>

TripwireManager::TripwireManager(QObject *parent)
    : QObject(parent)
    , m_nextId(1)
{
}

QString TripwireManager::addTripwire(const QString &tileId, const QPointF &start, const QPointF &end)
{
    QString id = QString("tripwire_%1").arg(m_nextId++);
    m_tripwires.append(Tripwire(id, tileId, start, end));
    emit tripwiresChanged();
    qDebug() << "Tripwire added:" << id << "for tile" << tileId << "from" << start << "to" << end;
    return id;
}

void TripwireManager::removeTripwire(const QString &id)
{
    int index = findTripwireIndex(id);
    if (index >= 0) {
        m_tripwires.removeAt(index);
        emit tripwiresChanged();
        qDebug() << "Tripwire removed:" << id;
    }
}

void TripwireManager::clearTripwires()
{
    m_tripwires.clear();
    emit tripwiresChanged();
}

void TripwireManager::clearTripwiresForCamera(const QString &tileId)
{
    for (int i = m_tripwires.size() - 1; i >= 0; --i) {
        if (m_tripwires[i].tileId == tileId) {
            m_tripwires.removeAt(i);
        }
    }
    emit tripwiresChanged();
}

QList<QPointF> TripwireManager::getTripwirePoints(const QString &id)
{
    int index = findTripwireIndex(id);
    if (index >= 0) {
        QList<QPointF> points;
        points.append(m_tripwires[index].startPoint);
        points.append(m_tripwires[index].endPoint);
        return points;
    }
    return QList<QPointF>();
}

void TripwireManager::setTripwireEnabled(const QString &id, bool enabled)
{
    int index = findTripwireIndex(id);
    if (index >= 0) {
        m_tripwires[index].enabled = enabled;
        emit tripwiresChanged();
    }
}

QString TripwireManager::addROI(const QString &tileId, const QVariantList &points)
{
    if (points.size() < 3) {
        qDebug() << "ROI must have at least 3 points";
        return QString();
    }
    
    QPolygonF polygon;
    for (const QVariant &pointVar : points) {
        QVariantMap pointMap = pointVar.toMap();
        if (pointMap.contains("x") && pointMap.contains("y")) {
            polygon << QPointF(pointMap["x"].toDouble(), pointMap["y"].toDouble());
        }
    }
    
    if (polygon.size() < 3) {
        qDebug() << "ROI must have at least 3 valid points";
        return QString();
    }
    
    QString id = QString("roi_%1").arg(m_nextId++);
    m_rois.append(ROI(id, tileId, polygon));
    emit roisChanged();
    qDebug() << "ROI added:" << id << "for tile" << tileId << "with" << polygon.size() << "points";
    return id;
}

void TripwireManager::removeROI(const QString &id)
{
    int index = findROIIndex(id);
    if (index >= 0) {
        m_rois.removeAt(index);
        emit roisChanged();
        qDebug() << "ROI removed:" << id;
    }
}

void TripwireManager::clearROIs()
{
    m_rois.clear();
    emit roisChanged();
}

void TripwireManager::clearROIsForCamera(const QString &tileId)
{
    for (int i = m_rois.size() - 1; i >= 0; --i) {
        if (m_rois[i].tileId == tileId) {
            m_rois.removeAt(i);
        }
    }
    emit roisChanged();
}

QList<QPointF> TripwireManager::getROIPoints(const QString &id)
{
    int index = findROIIndex(id);
    if (index >= 0) {
        // QPolygonF is already a QList<QPointF> in Qt 6
        return m_rois[index].polygon;
    }
    return QList<QPointF>();
}

void TripwireManager::setROIEnabled(const QString &id, bool enabled)
{
    int index = findROIIndex(id);
    if (index >= 0) {
        m_rois[index].enabled = enabled;
        emit roisChanged();
    }
}

bool TripwireManager::checkTripwireCrossing(const QString &tripwireId, const QPointF &from, const QPointF &to)
{
    int index = findTripwireIndex(tripwireId);
    if (index < 0 || !m_tripwires[index].enabled)
        return false;
    
    const Tripwire &tripwire = m_tripwires[index];
    QPointF intersection;
    
    // Check if movement line crosses tripwire line
    // Use BoundedIntersection to ensure the crossing is within both line segments
    if (lineIntersection(from, to, tripwire.startPoint, tripwire.endPoint, intersection)) {
        // Cooldown: prevent multiple alerts within 1.5 seconds (reduced from 2s for better responsiveness)
        qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
        qint64 timeSinceLastCross = currentTime - m_tripwires[index].lastCrossTime;
        
        if (timeSinceLastCross > 1500) {  // 1.5 second cooldown
            m_tripwires[index].crossCount++;
            m_tripwires[index].lastCrossTime = currentTime;
            emit tripwireCrossed(tripwireId, intersection);
            qDebug() << "Tripwire crossed:" << tripwireId << "at" << intersection << "from" << from << "to" << to;
            return true;
        } else {
            qDebug() << "Tripwire crossing ignored (cooldown):" << tripwireId << "time since last:" << timeSinceLastCross;
        }
    }
    
    return false;
}

bool TripwireManager::checkROIEntry(const QString &roiId, const QPointF &point)
{
    int index = findROIIndex(roiId);
    if (index < 0 || !m_rois[index].enabled)
        return false;
    
    ROI &roi = m_rois[index];
    bool isInside = pointInPolygon(point, roi.polygon);
    
    if (isInside && !roi.motionInside) {
        // Cooldown: prevent multiple alerts within 2 seconds
        qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
        qint64 timeSinceLastEntry = currentTime - m_rois[index].lastEntryTime;
        
        if (timeSinceLastEntry > 2000) {  // 2 second cooldown
            roi.motionInside = true;
            m_rois[index].lastEntryTime = currentTime;
            emit roiEntered(roiId, point);
            qDebug() << "ROI entered:" << roiId << "at" << point;
            return true;
        }
    } else if (!isInside && roi.motionInside) {
        roi.motionInside = false;
        emit roiExited(roiId, point);
        qDebug() << "ROI exited:" << roiId << "at" << point;
    }
    
    return false;
}

bool TripwireManager::isPointInROI(const QString &roiId, const QPointF &point)
{
    int index = findROIIndex(roiId);
    if (index < 0)
        return false;
    
    return pointInPolygon(point, m_rois[index].polygon);
}

QVariantList TripwireManager::getAllTripwires(const QString &tileId)
{
    QVariantList result;
    for (const Tripwire &tw : std::as_const(m_tripwires)) {
        // Filter by tileId if provided
        if (!tileId.isEmpty() && tw.tileId != tileId) {
            continue;
        }
        QVariantMap map;
        map["id"] = tw.id;
        map["startX"] = tw.startPoint.x();
        map["startY"] = tw.startPoint.y();
        map["endX"] = tw.endPoint.x();
        map["endY"] = tw.endPoint.y();
        map["enabled"] = tw.enabled;
        result.append(map);
    }
    return result;
}

QVariantList TripwireManager::getAllROIs(const QString &tileId)
{
    QVariantList result;
    for (const ROI &roi : std::as_const(m_rois)) {
        // Filter by tileId if provided
        if (!tileId.isEmpty() && roi.tileId != tileId) {
            continue;
        }
        QVariantMap map;
        map["id"] = roi.id;
        QVariantList points;
        for (const QPointF &point : std::as_const(roi.polygon)) {
            QVariantMap p;
            p["x"] = point.x();
            p["y"] = point.y();
            points.append(p);
        }
        map["points"] = points;
        map["enabled"] = roi.enabled;
        result.append(map);
    }
    return result;
}

bool TripwireManager::lineIntersection(const QPointF &p1, const QPointF &p2,
                                      const QPointF &p3, const QPointF &p4, QPointF &intersection)
{
    QLineF line1(p1, p2);
    QLineF line2(p3, p4);
    
    QLineF::IntersectType type = line1.intersects(line2, &intersection);
    return type == QLineF::BoundedIntersection;
}

bool TripwireManager::pointInPolygon(const QPointF &point, const QPolygonF &polygon)
{
    if (polygon.size() < 3)
        return false;
    
    // Ray casting algorithm
    int intersections = 0;
    int n = polygon.size();
    
    for (int i = 0; i < n; i++) {
        const QPointF &p1 = polygon[i];
        const QPointF &p2 = polygon[(i + 1) % n];
        
        if (((p1.y() > point.y()) != (p2.y() > point.y())) &&
            (point.x() < (p2.x() - p1.x()) * (point.y() - p1.y()) / (p2.y() - p1.y()) + p1.x())) {
            intersections++;
        }
    }
    
    return (intersections % 2) == 1;
}

int TripwireManager::findTripwireIndex(const QString &id)
{
    for (int i = 0; i < m_tripwires.size(); i++) {
        if (m_tripwires[i].id == id)
            return i;
    }
    return -1;
}

int TripwireManager::findROIIndex(const QString &id)
{
    for (int i = 0; i < m_rois.size(); i++) {
        if (m_rois[i].id == id)
            return i;
    }
    return -1;
}

