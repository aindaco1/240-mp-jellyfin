#include <QtTest>

#include <QJsonObject>

#include "modules/tumblr_screensaver/TumblrScreensaverBackend.h"

class TumblrScreensaverBackendTest final : public QObject {
    Q_OBJECT

private slots:
    void normalizesBlogUrls_data();
    void normalizesBlogUrls();
    void preservesGifFromPhotoFields();
    void preservesGifFromHtml();
};

void TumblrScreensaverBackendTest::normalizesBlogUrls_data()
{
    QTest::addColumn<QString>("input");
    QTest::addColumn<QString>("expected");

    QTest::newRow("short name")
        << QStringLiteral("pixel-sky")
        << QStringLiteral("https://pixel-sky.tumblr.com/");
    QTest::newRow("tumblr path")
        << QStringLiteral("https://www.tumblr.com/pixel-sky/posts")
        << QStringLiteral("https://pixel-sky.tumblr.com/");
    QTest::newRow("custom domain")
        << QStringLiteral("http://example.com/archive?before=2")
        << QStringLiteral("https://example.com/");
    QTest::newRow("invalid") << QStringLiteral("https://") << QString();
}

void TumblrScreensaverBackendTest::normalizesBlogUrls()
{
    QFETCH(QString, input);
    QFETCH(QString, expected);
    TumblrScreensaverBackend backend;
    QCOMPARE(backend.normalizeBlogUrl(input), expected);
}

void TumblrScreensaverBackendTest::preservesGifFromPhotoFields()
{
    TumblrScreensaverBackend backend;
    const QJsonObject post{
        {"slug", "animated-post"},
        {"photo-url-1280", "https://64.media.tumblr.com/still.jpg"},
        {"photo-url-500", "https://64.media.tumblr.com/animation.gif"}
    };

    const QVariantList images = backend.imagesFromPost(post);
    QCOMPARE(images.size(), 1);
    const QVariantMap image = images.first().toMap();
    QCOMPARE(image.value(QStringLiteral("url")).toString(),
             QStringLiteral("https://64.media.tumblr.com/animation.gif"));
    QCOMPARE(image.value(QStringLiteral("animated")).toBool(), true);
}

void TumblrScreensaverBackendTest::preservesGifFromHtml()
{
    TumblrScreensaverBackend backend;
    const QJsonObject post{
        {"regular-body",
         "<img src='https://64.media.tumblr.com/animation.gifv' "
         "srcset='https://64.media.tumblr.com/still.jpg 1280w'>"}
    };

    const QVariantList images = backend.imagesFromPost(post);
    QCOMPARE(images.size(), 1);
    const QVariantMap image = images.first().toMap();
    QCOMPARE(image.value(QStringLiteral("url")).toString(),
             QStringLiteral("https://64.media.tumblr.com/animation.gif"));
    QCOMPARE(image.value(QStringLiteral("animated")).toBool(), true);
}

QTEST_GUILESS_MAIN(TumblrScreensaverBackendTest)
#include "TumblrScreensaverBackendTest.moc"
