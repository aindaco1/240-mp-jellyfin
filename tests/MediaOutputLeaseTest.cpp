#include <QtTest>

#include <QQmlComponent>
#include <QQmlEngine>

class FakeMediaOutputHost final : public QObject {
    Q_OBJECT

public:
    int openCount = 0;
    int closeCount = 0;
    bool lastOpaque = false;
    bool lastAcceptsFocus = true;

    Q_INVOKABLE bool openMediaOutput(bool opaque, bool acceptsFocus)
    {
        ++openCount;
        lastOpaque = opaque;
        lastAcceptsFocus = acceptsFocus;
        return true;
    }

    Q_INVOKABLE void closeMediaOutput()
    {
        ++closeCount;
    }
};

class MediaOutputLeaseTest final : public QObject {
    Q_OBJECT

private slots:
    void opensOnlyWhileRequested();
    void disablingActiveLeaseClosesOutput();
    void destroyingActiveLeaseClosesOutput();

private:
    QObject *createLease(QQmlComponent &component, FakeMediaOutputHost &host);
};

QObject *MediaOutputLeaseTest::createLease(QQmlComponent &component,
                                            FakeMediaOutputHost &host)
{
    QObject *lease = component.createWithInitialProperties({
        {QStringLiteral("host"), QVariant::fromValue(&host)}
    });
    if (!lease)
        qWarning().noquote() << component.errorString();
    return lease;
}

void MediaOutputLeaseTest::opensOnlyWhileRequested()
{
    QQmlEngine engine;
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/MediaOutputLease.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    FakeMediaOutputHost host;
    QScopedPointer<QObject> lease(createLease(component, host));
    QVERIFY(lease);

    QVERIFY(lease->setProperty("enabled", true));
    QCOMPARE(host.openCount, 0);
    QCOMPARE(host.closeCount, 0);

    QVERIFY(lease->setProperty("requested", true));
    QCOMPARE(host.openCount, 1);
    QCOMPARE(host.closeCount, 0);
    QVERIFY(lease->property("active").toBool());
    QVERIFY(host.lastOpaque);
    QVERIFY(!host.lastAcceptsFocus);

    QVERIFY(lease->setProperty("requested", true));
    QCOMPARE(host.openCount, 1);

    QVERIFY(lease->setProperty("requested", false));
    QCOMPARE(host.closeCount, 1);
    QVERIFY(!lease->property("active").toBool());
}

void MediaOutputLeaseTest::disablingActiveLeaseClosesOutput()
{
    QQmlEngine engine;
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/MediaOutputLease.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    FakeMediaOutputHost host;
    QScopedPointer<QObject> lease(createLease(component, host));
    QVERIFY(lease);
    QVERIFY(lease->setProperty("enabled", true));
    QVERIFY(lease->setProperty("requested", true));
    QCOMPARE(host.openCount, 1);

    QVERIFY(lease->setProperty("enabled", false));
    QCOMPARE(host.closeCount, 1);
    QVERIFY(!lease->property("active").toBool());
}

void MediaOutputLeaseTest::destroyingActiveLeaseClosesOutput()
{
    QQmlEngine engine;
    QQmlComponent component(
        &engine,
        QUrl::fromLocalFile(QStringLiteral(
            TEST_SOURCE_ROOT "/views/Components/MediaOutputLease.qml")));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));

    FakeMediaOutputHost host;
    QScopedPointer<QObject> lease(createLease(component, host));
    QVERIFY(lease);
    QVERIFY(lease->setProperty("enabled", true));
    QVERIFY(lease->setProperty("requested", true));
    QCOMPARE(host.openCount, 1);

    lease.reset();
    QCOMPARE(host.closeCount, 1);
}

QTEST_GUILESS_MAIN(MediaOutputLeaseTest)
#include "MediaOutputLeaseTest.moc"
