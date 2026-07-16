#include <QtTest>

#include "update/UpdateManager.h"

class UpdateManagerTest final : public QObject {
    Q_OBJECT

private slots:
    void comparesVersions_data();
    void comparesVersions();
};

void UpdateManagerTest::comparesVersions_data() {
    QTest::addColumn<QString>("left");
    QTest::addColumn<QString>("right");
    QTest::addColumn<int>("expected");

    QTest::newRow("new patch") << QStringLiteral("1.1.1") << QStringLiteral("1.1.0") << 1;
    QTest::newRow("v prefix") << QStringLiteral("v1.1.0") << QStringLiteral("1.1") << 0;
    QTest::newRow("older minor") << QStringLiteral("1.0.9") << QStringLiteral("1.1.0") << -1;
    QTest::newRow("double digit") << QStringLiteral("1.10.0") << QStringLiteral("1.2.0") << 1;
    QTest::newRow("prerelease suffix") << QStringLiteral("1.1.0-rc1") << QStringLiteral("1.1.0") << 0;
}

void UpdateManagerTest::comparesVersions() {
    QFETCH(QString, left);
    QFETCH(QString, right);
    QFETCH(int, expected);
    QCOMPARE(UpdateManager::compareVersions(left, right), expected);
}

QTEST_MAIN(UpdateManagerTest)
#include "UpdateManagerTest.moc"
