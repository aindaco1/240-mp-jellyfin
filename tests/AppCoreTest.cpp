#include "AppCore.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJSEngine>
#include <QSignalSpy>
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
    void discoversNatureInExpectedOrder();
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

void AppCoreTest::discoversNatureInExpectedOrder()
{
    QTemporaryDir data;
    QVERIFY(data.isValid());
    AppCore core(QStringLiteral(TEST_SOURCE_ROOT), data.path());
    QSignalSpy modulesSpy(&core, &AppCore::modulesLoaded);

    core.scan_for_modules();
    QCOMPARE(modulesSpy.size(), 1);
    const QVariantList modules = modulesSpy.constFirst().constFirst().toList();
    QStringList names;
    for (const QVariant &module : modules)
        names.append(module.toMap().value(QStringLiteral("name")).toString());
    QCOMPARE(names, QStringList({QStringLiteral("Jellyfin"), QStringLiteral("Karaoke"),
                                 QStringLiteral("Retro"), QStringLiteral("Tumblr"),
                                 QStringLiteral("Nature"), QStringLiteral("Local"),
                                 QStringLiteral("Loop")}));

    const QVariantMap nature = core.get_module_info(QStringLiteral("com.240mp.nature")).toMap();
    QCOMPARE(nature.value(QStringLiteral("name")).toString(), QStringLiteral("Nature"));
    QVERIFY(nature.value(QStringLiteral("icon")).toUrl().isValid());
}

QTEST_MAIN(AppCoreTest)
#include "AppCoreTest.moc"
