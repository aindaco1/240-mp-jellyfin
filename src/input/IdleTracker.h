#pragma once

#include <QObject>
#include <QTimer>

class IdleTracker final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int threshold READ threshold WRITE setThreshold NOTIFY thresholdChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool mpvActive READ mpvActive WRITE setMpvActive NOTIFY mpvActiveChanged)

public:
    explicit IdleTracker(QObject *parent = nullptr);
    bool active() const { return m_active; }
    int threshold() const { return m_threshold; }
    bool enabled() const { return m_enabled; }
    bool mpvActive() const { return m_mpvActive; }
    void setThreshold(int seconds);
    void setEnabled(bool enabled);
    void setMpvActive(bool active);
    Q_INVOKABLE void resetActivity();

signals:
    void activeChanged();
    void thresholdChanged();
    void enabledChanged();
    void mpvActiveChanged();

protected:
    bool eventFilter(QObject *object, QEvent *event) override;

private:
    QTimer m_timer;
    int m_threshold = 60;
    int m_idleSeconds = 0;
    bool m_active = false;
    bool m_enabled = false;
    bool m_mpvActive = false;
};
