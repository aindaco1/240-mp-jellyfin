#include "AppCore.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

class BackendWithoutAuth final : public QObject {
    Q_OBJECT
};

class AppCoreTest final : public QObject {
    Q_OBJECT

private slots:
    void dottedSettingsRoundTrip();
    void nonAuthBackendReturnsNoAuthState();
};

void AppCoreTest::dottedSettingsRoundTrip()
{
    QTemporaryDir root;
    QTemporaryDir data;
    QVERIFY(root.isValid());
    QVERIFY(data.isValid());

    AppCore core(root.path(), data.path());
    core.save_setting(QStringLiteral("com.example.module"),
                      QStringLiteral("remote_keymap.select"),
                      QStringLiteral("Return"));

    QCOMPARE(core.get_setting(QStringLiteral("com.example.module"),
                              QStringLiteral("remote_keymap.select")).toString(),
             QStringLiteral("Return"));
}

void AppCoreTest::nonAuthBackendReturnsNoAuthState()
{
    QTemporaryDir root;
    QTemporaryDir data;
    QVERIFY(root.isValid());
    QVERIFY(data.isValid());

    AppCore core(root.path(), data.path());
    BackendWithoutAuth backend;
    core.registerModule(QStringLiteral("com.example.module"), QString(), &backend, nullptr);
    QCOMPARE(core.get_module_auth_state(QStringLiteral("com.example.module")), QString());
}

QTEST_MAIN(AppCoreTest)
#include "AppCoreTest.moc"
