#include "IdleTracker.h"

#include <QCoreApplication>
#include <QEvent>
#include <QKeyEvent>

IdleTracker::IdleTracker(QObject *parent) : QObject(parent) {
    QCoreApplication::instance()->installEventFilter(this);
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, [this]() {
        if (!m_enabled || m_active || m_mpvActive) return;
        if (++m_idleSeconds >= m_threshold) {
            m_active = true;
            emit activeChanged();
        }
    });
    m_timer.start();
}

void IdleTracker::setThreshold(int seconds) {
    seconds = qMax(1, seconds);
    if (m_threshold == seconds) return;
    m_threshold = seconds;
    emit thresholdChanged();
    resetActivity();
}

void IdleTracker::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    emit enabledChanged();
    resetActivity();
}

void IdleTracker::setMpvActive(bool active) {
    if (m_mpvActive == active) return;
    m_mpvActive = active;
    emit mpvActiveChanged();
    resetActivity();
}

void IdleTracker::resetActivity() {
    m_idleSeconds = 0;
    if (m_active) {
        m_active = false;
        emit activeChanged();
    }
}

bool IdleTracker::eventFilter(QObject *object, QEvent *event) {
    Q_UNUSED(object)
    const QEvent::Type type = event->type();
    if (type == QEvent::KeyPress) {
        if (!static_cast<QKeyEvent *>(event)->isAutoRepeat()) resetActivity();
    } else if (type == QEvent::MouseButtonPress || type == QEvent::MouseMove ||
               type == QEvent::TouchBegin) {
        resetActivity();
    }
    return false;
}
