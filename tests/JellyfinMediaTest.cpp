#include <QFile>
#include <QJSEngine>
#include <QJSValue>
#include <QtTest>

class JellyfinMediaTest final : public QObject {
    Q_OBJECT

private slots:
    void episodeListTitlesIncludeSeriesAndCodeWithoutDuplication();
};

void JellyfinMediaTest::episodeListTitlesIncludeSeriesAndCodeWithoutDuplication()
{
    QFile source(QStringLiteral(TEST_SOURCE_ROOT "/modules/jellyfin/views/JellyfinMedia.js"));
    QVERIFY(source.open(QIODevice::ReadOnly | QIODevice::Text));
    QString script = QString::fromUtf8(source.readAll());
    script.remove(QStringLiteral(".pragma library"));

    QJSEngine engine;
    const QJSValue result = engine.evaluate(script, source.fileName());
    QVERIFY2(!result.isError(), qPrintable(result.toString()));

    QJSValue episode = engine.newObject();
    episode.setProperty(QStringLiteral("type"), QStringLiteral("episode"));
    episode.setProperty(QStringLiteral("title"), QStringLiteral("S01E02 - Pilot"));
    episode.setProperty(QStringLiteral("name"), QStringLiteral("Pilot"));
    episode.setProperty(QStringLiteral("episodeCode"), QStringLiteral("S01E02"));
    episode.setProperty(QStringLiteral("seriesName"), QStringLiteral("Example Show"));

    const QJSValue listTitle = engine.globalObject().property(QStringLiteral("listTitle"));
    QVERIFY(listTitle.isCallable());
    QCOMPARE(listTitle.call({episode, true}).toString(),
             QStringLiteral("Example Show - S01E02: Pilot"));
    QCOMPARE(listTitle.call({episode, false}).toString(),
             QStringLiteral("S01E02: Pilot"));
}

QTEST_GUILESS_MAIN(JellyfinMediaTest)
#include "JellyfinMediaTest.moc"
