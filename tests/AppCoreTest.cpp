#include "AppCore.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJSEngine>
#include <QTemporaryDir>
#include <QtTest>

class BackendWithoutAuth final : public QObject {
    Q_OBJECT
};

class AppCoreTest final : public QObject {
    Q_OBJECT

private slots:
    void dottedSettingsRoundTrip();
    void listSettingsRoundTrip();
    void qmlListSettingsRoundTrip();
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

void AppCoreTest::qmlListSettingsRoundTrip()
{
    QTemporaryDir root;
    QTemporaryDir data;
    QVERIFY(root.isValid());
    QVERIFY(data.isValid());

    AppCore core(root.path(), data.path());
    QJSEngine engine;
    const QJSValue favorites = engine.evaluate(
        QStringLiteral("['https://one.tumblr.com/', 'https://two.tumblr.com/']"));
    core.save_setting(QStringLiteral("com.240mp.tumblr_screensaver"),
                      QStringLiteral("favorites"), QVariant::fromValue(favorites));

    QCOMPARE(core.get_setting(QStringLiteral("com.240mp.tumblr_screensaver"),
                              QStringLiteral("favorites")).toStringList(),
             QStringList({QStringLiteral("https://one.tumblr.com/"),
                          QStringLiteral("https://two.tumblr.com/")}));
}

void AppCoreTest::listSettingsRoundTrip()
{
    QTemporaryDir root;
    QTemporaryDir data;
    QVERIFY(root.isValid());
    QVERIFY(data.isValid());

    AppCore core(root.path(), data.path());
    const QStringList favorites = {
        QStringLiteral("https://example-one.tumblr.com/"),
        QStringLiteral("https://example-two.tumblr.com/")
    };
    core.save_setting(QStringLiteral("com.240mp.tumblr_screensaver"),
                      QStringLiteral("favorites"), favorites);

    QCOMPARE(core.get_setting(QStringLiteral("com.240mp.tumblr_screensaver"),
                              QStringLiteral("favorites")).toStringList(),
             favorites);
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
