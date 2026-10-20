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
    // Accept both bounded and unbounded intersections for better detection
    if (lineIntersection(from, to, tripwire.startPoint, tripwire.endPoint, intersection)) {
        // Verify intersection is reasonable (within reasonable bounds of tripwire)
        QLineF tripwireLine(tripwire.startPoint, tripwire.endPoint);
        double tripwireLength = tripwireLine.length();
        
        // Calculate distance from intersection to tripwire start/end
        double distToStart = QLineF(tripwire.startPoint, intersection).length();
        double distToEnd = QLineF(tripwire.endPoint, intersection).length();
        
        // Accept if intersection is within tripwire segment or very close (within 20% extension)
        bool withinBounds = (distToStart <= tripwireLength * 1.2 && distToEnd <= tripwireLength * 1.2);
        
        if (withinBounds) {
            // Cooldown: prevent multiple alerts within 1 second
            qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
            qint64 timeSinceLastCross = currentTime - m_tripwires[index].lastCrossTime;
            
            if (timeSinceLastCross > 1000) {  // 1 second cooldown
                m_tripwires[index].crossCount++;
                m_tripwires[index].lastCrossTime = currentTime;
                emit tripwireCrossed(tripwireId, intersection);
                qDebug() << "Tripwire crossed:" << tripwireId << "at" << intersection << "from" << from << "to" << to;
                return true;
            } else {
                qDebug() << "Tripwire crossing ignored (cooldown):" << tripwireId << "time since last:" << timeSinceLastCross;
            }
        }
    }
    
    return false;
}

bool TripwireManager::checkTripwireProximity(const QString &tripwireId, const QPointF &point, double threshold)
{
    int index = findTripwireIndex(tripwireId);
    if (index < 0 || !m_tripwires[index].enabled)
        return false;
    
    const Tripwire &tripwire = m_tripwires[index];
    
    // Calculate distance from point to line segment using vector math
    QPointF lineVec = tripwire.endPoint - tripwire.startPoint;
    QPointF pointVec = point - tripwire.startPoint;
    
    double lineLengthSq = lineVec.x() * lineVec.x() + lineVec.y() * lineVec.y();
    if (lineLengthSq < 0.0001)  // Very short line, skip
        return false;
    
    // Project point onto line
    double t = (pointVec.x() * lineVec.x() + pointVec.y() * lineVec.y()) / lineLengthSq;
    
    // Clamp t to [0, 1] to stay within segment
    t = qBound(0.0, t, 1.0);
    
    // Find closest point on line segment
    QPointF closestPoint = tripwire.startPoint + QPointF(t * lineVec.x(), t * lineVec.y());
    
    // Calculate distance from point to closest point on line
    double dx = point.x() - closestPoint.x();
    double dy = point.y() - closestPoint.y();
    double distance = qSqrt(dx * dx + dy * dy);
    
    // If within threshold, trigger crossing
    if (distance <= threshold) {
        // Cooldown check
        qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
        qint64 timeSinceLastCross = currentTime - m_tripwires[index].lastCrossTime;
        
        if (timeSinceLastCross > 1000) {  // 1 second cooldown
            m_tripwires[index].crossCount++;
            m_tripwires[index].lastCrossTime = currentTime;
            emit tripwireCrossed(tripwireId, closestPoint);
            qDebug() << "Tripwire proximity triggered:" << tripwireId << "distance:" << distance << "at" << point;
            return true;
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
    
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    
    if (isInside && !roi.motionInside) {
        // Reduced cooldown for better responsiveness
        qint64 timeSinceLastEntry = currentTime - m_rois[index].lastEntryTime;
        
        if (timeSinceLastEntry > 500) {  // 0.5 second cooldown for better responsiveness
            roi.motionInside = true;
            m_rois[index].lastEntryTime = currentTime;
            emit roiEntered(roiId, point);
            qDebug() << "ROI entered:" << roiId << "at" << point;
            return true;
        } else {
            qDebug() << "ROI entry ignored (cooldown):" << roiId << "time since last:" << timeSinceLastEntry;
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

void TripwireManager::resetROIState(const QString &roiId)
{
    int index = findROIIndex(roiId);
    if (index >= 0) {
        m_rois[index].motionInside = false;
        m_rois[index].lastEntryTime = 0;
        qDebug() << "ROI state reset:" << roiId;
    }
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
    // Accept both bounded and unbounded intersections for better detection
    // Unbounded allows detection even if movement extends beyond tripwire segment
    return (type == QLineF::BoundedIntersection || type == QLineF::UnboundedIntersection);
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
