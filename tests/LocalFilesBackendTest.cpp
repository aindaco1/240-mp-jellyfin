#include "modules/local_files/LocalFilesBackend.h"

#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class LocalFilesBackendTest final : public QObject {
    Q_OBJECT

private slots:
    void recognizesSupportedTypes();
    void enforcesPathBoundariesButAllowsRootSymlinks();
    void detectsRelativeImagesInPlaylists();
};

void LocalFilesBackendTest::recognizesSupportedTypes()
{
    QTemporaryDir app;
    QTemporaryDir data;
    LocalFilesBackend backend(app.path(), data.path());
    QVERIFY(backend.isImage(QStringLiteral("photo.WEBP")));
    QVERIFY(backend.isPlaylist(QStringLiteral("queue.m3u8")));
    QVERIFY(!backend.isImage(QStringLiteral("movie.mkv")));
}

void LocalFilesBackendTest::enforcesPathBoundariesButAllowsRootSymlinks()
{
    QTemporaryDir app;
    QTemporaryDir data;
    QTemporaryDir media;
    QTemporaryDir external;
    QVERIFY(app.isValid() && data.isValid() && media.isValid() && external.isValid());

    QFile externalMovie(external.filePath(QStringLiteral("linked.mp4")));
    QVERIFY(externalMovie.open(QIODevice::WriteOnly));
    externalMovie.close();
    QVERIFY(QFile::link(external.path(), media.filePath(QStringLiteral("linked"))));

    LocalFilesBackend backend(app.path(), data.path());
    backend.setMediaRoot(media.path());
    const QVariantList linked = backend.getItems(media.filePath(QStringLiteral("linked")));
    QCOMPARE(linked.size(), 1);
    QCOMPARE(linked.first().toMap().value(QStringLiteral("name")).toString(),
             QStringLiteral("linked.mp4"));

    QTemporaryDir sibling;
    QVERIFY(sibling.isValid());
    QCOMPARE(backend.getItems(sibling.path()).size(), 0);
}

void LocalFilesBackendTest::detectsRelativeImagesInPlaylists()
{
    QTemporaryDir app;
    QTemporaryDir data;
    QTemporaryDir media;
    QVERIFY(app.isValid() && data.isValid() && media.isValid());

    QFile image(media.filePath(QStringLiteral("still.png")));
    QVERIFY(image.open(QIODevice::WriteOnly));
    image.close();
    QFile playlist(media.filePath(QStringLiteral("show.m3u")));
    QVERIFY(playlist.open(QIODevice::WriteOnly | QIODevice::Text));
    playlist.write("#EXTM3U\nstill.png\n");
    playlist.close();

    LocalFilesBackend backend(app.path(), data.path());
    backend.setMediaRoot(media.path());
    QVERIFY(backend.playlistContainsImages(playlist.fileName()));
}

QTEST_MAIN(LocalFilesBackendTest)
#include "LocalFilesBackendTest.moc"
