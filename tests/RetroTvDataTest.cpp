#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJSEngine>
#include <QJSValue>
#include <QtTest>

class RetroTvDataTest final : public QObject {
    Q_OBJECT

private slots:
    void extractsCurrentViteScriptUrl();
    void extractsCurrentDecodeMapShape();
    void parsesDecodedChannelRecord();

private:
    bool loadSource(QJSEngine &engine);
    QJSValue identityDecodeMap(QJSEngine &engine);
};

bool RetroTvDataTest::loadSource(QJSEngine &engine)
{
    QFile source(QStringLiteral(
        TEST_SOURCE_ROOT "/modules/retro_tv/views/RetroTvData.js"));
    if (!source.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    QString script = QString::fromUtf8(source.readAll());
    script.remove(QStringLiteral(".pragma library"));
    const QJSValue result = engine.evaluate(script, source.fileName());
    if (result.isError())
        qWarning().noquote() << result.toString();
    return !result.isError();
}

QJSValue RetroTvDataTest::identityDecodeMap(QJSEngine &engine)
{
    QJSValue map = engine.newArray(32);
    for (int row = 0; row < 32; ++row) {
        QJSValue positions = engine.newArray(11);
        for (int column = 0; column < 11; ++column)
            positions.setProperty(column, column);
        map.setProperty(row, positions);
    }
    return map;
}

void RetroTvDataTest::extractsCurrentViteScriptUrl()
{
    QJSEngine engine;
    QVERIFY(loadSource(engine));

    const QJSValue extractor = engine.globalObject().property(
        QStringLiteral("extractMainScriptUrl"));
    QVERIFY(extractor.isCallable());
    const QJSValue result = extractor.call({
        QStringLiteral("https://80s.myretrotvs.com"),
        QStringLiteral("<script type=\"module\" crossorigin "
                       "src=\"/assets/index-AbC123.js\"></script>")
    });
    QCOMPARE(result.toString(),
             QStringLiteral("https://80s.myretrotvs.com/assets/index-AbC123.js"));
}

void RetroTvDataTest::extractsCurrentDecodeMapShape()
{
    QJSEngine engine;
    QVERIFY(loadSource(engine));

    QJsonArray map;
    for (int row = 0; row < 32; ++row) {
        QJsonArray positions;
        for (int column = 0; column < 11; ++column)
            positions.append(column);
        map.append(positions);
    }
    const QString script = QStringLiteral("const decoder = %1;")
        .arg(QString::fromUtf8(QJsonDocument(map).toJson(QJsonDocument::Compact)));

    const QJSValue extractor = engine.globalObject().property(
        QStringLiteral("extractDecodeMap"));
    QVERIFY(extractor.isCallable());
    const QJSValue result = extractor.call({script});
    QVERIFY(result.isArray());
    QCOMPARE(result.property(QStringLiteral("length")).toInt(), 32);
    QCOMPARE(result.property(0).property(QStringLiteral("length")).toInt(), 11);
}

void RetroTvDataTest::parsesDecodedChannelRecord()
{
    QJSEngine engine;
    QVERIFY(loadSource(engine));
    QVERIFY(!engine.evaluate(QStringLiteral(
        "Math.random = function() { return 0; }")).isError());

    QJSValue feed = engine.newObject();
    feed.setProperty(QStringLiteral("startYear"), 1980);

    QJSValue years = engine.newArray(1);
    years.setProperty(0, QStringLiteral("abcdefghijkc"));
    QJSValue payload = engine.newObject();
    payload.setProperty(QStringLiteral("x"), years);

    const QJSValue parser = engine.globalObject().property(
        QStringLiteral("parseChannels"));
    QVERIFY(parser.isCallable());
    const QJSValue result = parser.call({feed, payload, identityDecodeMap(engine)});
    QVERIFY(!result.isError());

    const QJSValue channels = result.property(QStringLiteral("channels"));
    QCOMPARE(channels.property(QStringLiteral("length")).toInt(), 1);
    const QJSValue channel = channels.property(0);
    QCOMPARE(channel.property(QStringLiteral("categoryCode")).toString(),
             QStringLiteral("c"));
    QCOMPARE(channel.property(QStringLiteral("year")).toInt(), 1980);
    const QJSValue clips = channel.property(QStringLiteral("clips"));
    QCOMPARE(clips.property(0).property(QStringLiteral("videoId")).toString(),
             QStringLiteral("abcdefghijk"));
    QCOMPARE(result.property(QStringLiteral("counts"))
                 .property(QStringLiteral("c")).toInt(), 1);
}

QTEST_GUILESS_MAIN(RetroTvDataTest)
#include "RetroTvDataTest.moc"
