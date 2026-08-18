#include <QtTest>

#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSet>
#include <QSignalSpy>

class TumblrMediaQmlTest final : public QObject {
    Q_OBJECT

private slots:
    void animatedGifAdvancesFrames();
    void shuffledDeckDoesNotRepeat();
    void emptyDeckExhausts();
    void failedItemsAreRetired();
};

void TumblrMediaQmlTest::animatedGifAdvancesFrames()
{
    QQmlEngine engine;
    const QUrl componentUrl = QUrl::fromLocalFile(
        QStringLiteral(TEST_SOURCE_ROOT "/views/Components/MontageMedia.qml"));
    QQmlComponent component(&engine, componentUrl);
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    QQuickWindow window;
    window.resize(16, 16);
    window.show();

    QScopedPointer<QObject> media(component.create());
    QVERIFY2(media, qPrintable(component.errorString()));
    auto *mediaItem = qobject_cast<QQuickItem *>(media.data());
    QVERIFY(mediaItem);
    mediaItem->setParentItem(window.contentItem());
    media->setProperty("width", 16);
    media->setProperty("height", 16);
    media->setProperty("animated", true);
    media->setProperty("source", QUrl(QStringLiteral(
        "data:image/gif;base64,"
        "R0lGODlhAgACAPcfAAAAACQAAEgAAGwAAJAAALQAANgAAPwAAAAkACQkAEgkAGwkAJAkALQkANgkAPwkAABIACRIAEhIAGxIAJBIALRIANhIAPxIAABsACRsAEhsAGxsAJBsALRsANhsAPxsAACQACSQAEiQAGyQAJCQALSQANiQAPyQAAC0ACS0AEi0AGy0AJC0ALS0ANi0APy0AADYACTYAEjYAGzYAJDYALTYANjYAPzYAAD8ACT8AEj8AGz8AJD8ALT8ANj8APz8AAAAVSQAVUgAVWwAVZAAVbQAVdgAVfwAVQAkVSQkVUgkVWwkVZAkVbQkVdgkVfwkVQBIVSRIVUhIVWxIVZBIVbRIVdhIVfxIVQBsVSRsVUhsVWxsVZBsVbRsVdhsVfxsVQCQVSSQVUiQVWyQVZCQVbSQVdiQVfyQVQC0VSS0VUi0VWy0VZC0VbS0Vdi0Vfy0VQDYVSTYVUjYVWzYVZDYVbTYVdjYVfzYVQD8VST8VUj8VWz8VZD8VbT8Vdj8Vfz8VQAAqiQAqkgAqmwAqpAAqrQAqtgAqvwAqgAkqiQkqkgkqmwkqpAkqrQkqtgkqvwkqgBIqiRIqkhIqmxIqpBIqrRIqthIqvxIqgBsqiRsqkhsqmxsqpBsqrRsqthsqvxsqgCQqiSQqkiQqmyQqpCQqrSQqtiQqvyQqgC0qiS0qki0qmy0qpC0qrS0qti0qvy0qgDYqiTYqkjYqmzYqpDYqrTYqtjYqvzYqgD8qiT8qkj8qmz8qpD8qrT8qtj8qvz8qgAA/yQA/0gA/2wA/5AA/7QA/9gA//wA/wAk/yQk/0gk/2wk/5Ak/7Qk/9gk//wk/wBI/yRI/0hI/2xI/5BI/7RI/9hI//xI/wBs/yRs/0hs/2xs/5Bs/7Rs/9hs//xs/wCQ/ySQ/0iQ/2yQ/5CQ/7SQ/9iQ//yQ/wC0/yS0/0i0/2y0/5C0/7S0/9i0//y0/wDY/yTY/0jY/2zY/5DY/7TY/9jY//zY/wD8/yT8/0j8/2z8/5D8/7T8/9j8//z8/yH/C05FVFNDQVBFMi4wAwEAAAAh+QQEMgAfACwAAAAAAgACAAAIBwD90fJXKyAAIfkEBTIAAAAsAQABAAEAAQAACAQAaQUEADs=")));

    QTRY_VERIFY_WITH_TIMEOUT(media->property("ready").toBool(), 2000);
    const int initialFrame = media->property("currentFrame").toInt();
    QTRY_VERIFY_WITH_TIMEOUT(media->property("currentFrame").toInt() != initialFrame, 2000);
}

void TumblrMediaQmlTest::shuffledDeckDoesNotRepeat()
{
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(TEST_SOURCE_ROOT "/views"));
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/ImageMontage.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    QScopedPointer<QObject> montage(component.create());
    QVERIFY2(montage, qPrintable(component.errorString()));

    QVariantList items;
    for (int i = 0; i < 8; ++i)
        items.append(QVariantMap{{QStringLiteral("id"), i}});
    QVERIFY(montage->setProperty("items", items));
    QVERIFY(QMetaObject::invokeMethod(montage.data(), "refillDeck"));

    const QVariantList firstDeck = montage->property("deck").toList();
    QCOMPARE(firstDeck.size(), items.size());
    QSet<int> unique;
    for (const QVariant &value : firstDeck)
        unique.insert(value.toInt());
    QCOMPARE(unique.size(), items.size());

    const int previous = firstDeck.first().toInt();
    QVERIFY(montage->setProperty("internalCurrentIndex", previous));
    QVERIFY(montage->setProperty("deck", QVariantList{}));
    QVERIFY(QMetaObject::invokeMethod(montage.data(), "refillDeck"));
    const QVariantList secondDeck = montage->property("deck").toList();
    QCOMPARE(secondDeck.size(), items.size());
    QVERIFY(secondDeck.first().toInt() != previous);
}

void TumblrMediaQmlTest::emptyDeckExhausts()
{
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(TEST_SOURCE_ROOT "/views"));
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/ImageMontage.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    QScopedPointer<QObject> montage(component.create());
    QVERIFY2(montage, qPrintable(component.errorString()));
    QSignalSpy exhaustedSpy(montage.data(), SIGNAL(exhausted()));
    QVERIFY(exhaustedSpy.isValid());

    QVERIFY(QMetaObject::invokeMethod(montage.data(), "start"));
    QCOMPARE(exhaustedSpy.count(), 1);
    QVERIFY(!montage->property("running").toBool());
}

void TumblrMediaQmlTest::failedItemsAreRetired()
{
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(TEST_SOURCE_ROOT "/views"));
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/ImageMontage.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    QScopedPointer<QObject> montage(component.create());
    QVERIFY2(montage, qPrintable(component.errorString()));
    const QVariantList items{
        QVariantMap{{QStringLiteral("url"), QStringLiteral("file:///definitely-missing-nature-a.jpg")}},
        QVariantMap{{QStringLiteral("url"), QStringLiteral("file:///definitely-missing-nature-b.jpg")}}
    };
    QVERIFY(montage->setProperty("items", items));
    QSignalSpy failedSpy(montage.data(), SIGNAL(itemFailed(QVariant)));
    QSignalSpy exhaustedSpy(montage.data(), SIGNAL(exhausted()));
    QVERIFY(failedSpy.isValid());
    QVERIFY(exhaustedSpy.isValid());

    QVERIFY(QMetaObject::invokeMethod(montage.data(), "start"));
    QTRY_COMPARE_WITH_TIMEOUT(exhaustedSpy.size(), 1, 2000);
    QCOMPARE(failedSpy.size(), 2);
    QCOMPARE(montage->property("failedItemCount").toInt(), 2);
    QVERIFY(!montage->property("running").toBool());
}

QTEST_MAIN(TumblrMediaQmlTest)
#include "TumblrMediaQmlTest.moc"
