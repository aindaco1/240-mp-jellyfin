#include <QtTest>

#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>

class AmbientModeQmlTest final : public QObject {
    Q_OBJECT

private slots:
    void longSelectorValueStaysBetweenControls();
};

void AmbientModeQmlTest::longSelectorValueStaysBetweenControls()
{
    QQmlEngine engine;
    const QUrl componentUrl = QUrl::fromLocalFile(
        QStringLiteral(TEST_SOURCE_ROOT "/modules/ambient_mode/views/PlaybackSelectorRow.qml"));
    QQmlComponent component(&engine, componentUrl);
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    QQuickWindow window;
    window.resize(492, 28);
    window.show();

    QScopedPointer<QObject> selector(component.create());
    QVERIFY2(selector, qPrintable(component.errorString()));
    auto *selectorItem = qobject_cast<QQuickItem *>(selector.data());
    QVERIFY(selectorItem);
    selectorItem->setParentItem(window.contentItem());
    selector->setProperty("width", 492);
    selector->setProperty("height", 28);
    selector->setProperty("label", QStringLiteral("Video"));
    selector->setProperty("value", QStringLiteral(
        "A VERY LONG LOOP VIDEO NAME THAT MUST NEVER COVER THE LABEL OR SELECTOR ARROWS.MP4"));
    selector->setProperty("canGoPrevious", true);
    selector->setProperty("canGoNext", true);

    auto *label = selector->findChild<QQuickItem *>(QStringLiteral("selectorLabel"));
    auto *previous = selector->findChild<QQuickItem *>(QStringLiteral("selectorPreviousArrow"));
    auto *value = selector->findChild<QQuickItem *>(QStringLiteral("selectorValue"));
    auto *next = selector->findChild<QQuickItem *>(QStringLiteral("selectorNextArrow"));
    QVERIFY(label);
    QVERIFY(previous);
    QVERIFY(value);
    QVERIFY(next);

    QTRY_VERIFY_WITH_TIMEOUT(value->width() > 0, 1000);
    const qreal labelRight = label->mapToItem(selectorItem, QPointF(label->width(), 0)).x();
    const qreal previousLeft = previous->mapToItem(selectorItem, QPointF(0, 0)).x();
    const qreal previousRight = previous->mapToItem(selectorItem, QPointF(previous->width(), 0)).x();
    const qreal valueLeft = value->mapToItem(selectorItem, QPointF(0, 0)).x();
    const qreal valueRight = value->mapToItem(selectorItem, QPointF(value->width(), 0)).x();
    const qreal nextLeft = next->mapToItem(selectorItem, QPointF(0, 0)).x();
    const qreal nextRight = next->mapToItem(selectorItem, QPointF(next->width(), 0)).x();

    QVERIFY(previousLeft > labelRight);
    QVERIFY(valueLeft >= previousRight);
    QVERIFY(valueRight <= nextLeft);
    QVERIFY(nextRight <= selectorItem->width());
    QVERIFY(value->property("truncated").toBool());
}

QTEST_MAIN(AmbientModeQmlTest)
#include "AmbientModeQmlTest.moc"
