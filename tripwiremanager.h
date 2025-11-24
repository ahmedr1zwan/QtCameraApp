#ifndef TRIPWIREMANAGER_H
#define TRIPWIREMANAGER_H

#include <QObject>
#include <QPointF>
#include <QPolygonF>
#include <QList>
#include <QString>

struct Tripwire {
    QString id;
    QString tileId;  // Which tile this tripwire belongs to (e.g., "tile_0", "tile_1")
    QPointF startPoint;
    QPointF endPoint;
    bool enabled;
    int crossCount;  // Track how many times crossed
    qint64 lastCrossTime;  // Timestamp of last crossing (for cooldown)
    
    Tripwire() : enabled(false), crossCount(0), lastCrossTime(0) {}
    Tripwire(const QString &id, const QString &tileId, const QPointF &start, const QPointF &end)
        : id(id), tileId(tileId), startPoint(start), endPoint(end), enabled(true), crossCount(0), lastCrossTime(0) {}
};

struct ROI {
    QString id;
    QString tileId;  // Which tile this ROI belongs to (e.g., "tile_0", "tile_1")
    QPolygonF polygon;
    bool enabled;
    bool motionInside;  // Track if motion is currently inside
    qint64 lastEntryTime;  // Timestamp of last entry (for cooldown)
    
    ROI() : enabled(false), motionInside(false), lastEntryTime(0) {}
    ROI(const QString &id, const QString &tileId, const QPolygonF &poly)
        : id(id), tileId(tileId), polygon(poly), enabled(true), motionInside(false), lastEntryTime(0) {}
};

class TripwireManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int tripwireCount READ tripwireCount NOTIFY tripwiresChanged)
    Q_PROPERTY(int roiCount READ roiCount NOTIFY roisChanged)

public:
    explicit TripwireManager(QObject *parent = nullptr);
    
    // Tripwire management
    Q_INVOKABLE QString addTripwire(const QString &tileId, const QPointF &start, const QPointF &end);
    Q_INVOKABLE void removeTripwire(const QString &id);
    Q_INVOKABLE void clearTripwires();
    Q_INVOKABLE void clearTripwiresForCamera(const QString &tileId);  // tileId parameter name kept for compatibility
    Q_INVOKABLE QList<QPointF> getTripwirePoints(const QString &id);
    Q_INVOKABLE void setTripwireEnabled(const QString &id, bool enabled);
    
    // ROI management
    Q_INVOKABLE QString addROI(const QString &tileId, const QVariantList &points);  // List of {x, y} objects
    Q_INVOKABLE void removeROI(const QString &id);
    Q_INVOKABLE void clearROIs();
    Q_INVOKABLE void clearROIsForCamera(const QString &tileId);  // tileId parameter name kept for compatibility
    Q_INVOKABLE QList<QPointF> getROIPoints(const QString &id);
    Q_INVOKABLE void setROIEnabled(const QString &id, bool enabled);
    
    // Detection methods (called from motion detector or object tracker)
    Q_INVOKABLE bool checkTripwireCrossing(const QString &tripwireId, const QPointF &from, const QPointF &to);
    Q_INVOKABLE bool checkTripwireProximity(const QString &tripwireId, const QPointF &point, double threshold = 0.02);
    Q_INVOKABLE bool checkROIEntry(const QString &roiId, const QPointF &point);
    Q_INVOKABLE bool isPointInROI(const QString &roiId, const QPointF &point);
    
    // Get all active tripwires/ROIs for drawing (filtered by tileId)
    Q_INVOKABLE QVariantList getAllTripwires(const QString &tileId = QString());
    Q_INVOKABLE QVariantList getAllROIs(const QString &tileId = QString());
    
    int tripwireCount() const { return m_tripwires.size(); }
    int roiCount() const { return m_rois.size(); }

signals:
    void tripwiresChanged();
    void roisChanged();
    void tripwireCrossed(const QString &tripwireId, const QPointF &point);
    void roiEntered(const QString &roiId, const QPointF &point);
    void roiExited(const QString &roiId, const QPointF &point);

private:
    QList<Tripwire> m_tripwires;
    QList<ROI> m_rois;
    int m_nextId;
    
    // Helper methods
    bool lineIntersection(const QPointF &p1, const QPointF &p2, 
                         const QPointF &p3, const QPointF &p4, QPointF &intersection);
    bool pointInPolygon(const QPointF &point, const QPolygonF &polygon);
    int findTripwireIndex(const QString &id);
    int findROIIndex(const QString &id);
};

#endif // TRIPWIREMANAGER_H

