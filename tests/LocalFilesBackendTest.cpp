#include "modules/local_files/LocalFilesBackend.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class LocalFilesBackendTest final : public QObject {
    Q_OBJECT

private slots:
    void recognizesSupportedTypes();
    void enforcesPathBoundariesButAllowsRootSymlinks();
    void detectsRelativeImagesInPlaylists();
    void persistsDuplicateQueuesAndExpandsLocalPlaylists();
    void retainsFailedEntriesAndPreparesSelectedPlayback();
    void changingMediaRootPrunesOutOfRootQueueItems();
    void usesBundledMpvForSeparateAudio();
};

static bool writeFile(const QString &path, const QByteArray &contents = {})
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    return file.write(contents) == contents.size();
}

static bool writeLocalConfig(const QString &dataRoot, const QString &mediaRoot)
{
    const QJsonObject config{{QStringLiteral("modules"), QJsonObject{
        {QStringLiteral("com.240mp.local_files"), QJsonObject{
            {QStringLiteral("media_directory"), mediaRoot}
        }},
        {QStringLiteral("com.240mp.ambient_mode"), QJsonObject{
            {QStringLiteral("media_directory"), QStringLiteral("/ignored/legacy/loop")}
        }}
    }}};
    return writeFile(QDir(dataRoot).filePath(QStringLiteral("config.json")),
                     QJsonDocument(config).toJson(QJsonDocument::Compact));
}

void LocalFilesBackendTest::recognizesSupportedTypes()
{
    QTemporaryDir app;
    QTemporaryDir data;
    LocalFilesBackend backend(app.path(), data.path());
    QVERIFY(backend.isImage(QStringLiteral("photo.WEBP")));
    QVERIFY(backend.isAudio(QStringLiteral("soundtrack.FLAC")));
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

void LocalFilesBackendTest::persistsDuplicateQueuesAndExpandsLocalPlaylists()
{
    QTemporaryDir app;
    QTemporaryDir data;
    QTemporaryDir media;
    QTemporaryDir outside;
    QVERIFY(app.isValid() && data.isValid() && media.isValid() && outside.isValid());
    QVERIFY(writeLocalConfig(data.path(), media.path()));

    const QString first = media.filePath(QStringLiteral("first.mp4"));
    const QString second = media.filePath(QStringLiteral("second.png"));
    const QString audio = media.filePath(QStringLiteral("bed.flac"));
    const QString outsideFile = outside.filePath(QStringLiteral("outside.mp4"));
    QVERIFY(writeFile(first));
    QVERIFY(writeFile(second));
    QVERIFY(writeFile(audio));
    QVERIFY(writeFile(outsideFile));

    const QString nestedPath = media.filePath(QStringLiteral("nested.m3u8"));
    QVERIFY(writeFile(nestedPath, QByteArrayLiteral("#EXTM3U\nsecond.png\n")));
    const QString playlistPath = media.filePath(QStringLiteral("queue.m3u"));
    const QByteArray playlist = QByteArrayLiteral("#EXTM3U\nfirst.mp4\nnested.m3u8\n")
        + QFile::encodeName(outsideFile) + QByteArrayLiteral("\nhttps://example.com/remote.mp4\n");
    QVERIFY(writeFile(playlistPath, playlist));

    {
        LocalFilesBackend backend(app.path(), data.path());
        QCOMPARE(backend.mediaRoot(), media.path());
        QCOMPARE(backend.getItems(media.path()).size(), 5); // 3 media files + 2 playlists
        QCOMPARE(backend.enqueue(QStringLiteral("media"),
                                 {{QStringLiteral("filePath"), playlistPath}}), 2);
        QCOMPARE(backend.enqueue(QStringLiteral("media"),
                                 {{QStringLiteral("filePath"), first}}), 1);
        QCOMPARE(backend.enqueue(QStringLiteral("soundtrack"),
                                 {{QStringLiteral("filePath"), audio}}), 1);
        QCOMPARE(backend.enqueue(QStringLiteral("soundtrack"),
                                 {{QStringLiteral("filePath"), first}}), 0);
        const QVariantList queue = backend.getQueue(QStringLiteral("media"));
        QCOMPARE(queue.size(), 3);
        QCOMPARE(queue.at(0).toMap().value(QStringLiteral("filePath")).toString(), first);
        QCOMPARE(queue.at(2).toMap().value(QStringLiteral("filePath")).toString(), first);
        QVERIFY(queue.at(0).toMap().value(QStringLiteral("entryId")) !=
                queue.at(2).toMap().value(QStringLiteral("entryId")));
    }

    LocalFilesBackend reloaded(app.path(), data.path());
    QCOMPARE(reloaded.getQueue(QStringLiteral("media")).size(), 3);
    QCOMPARE(reloaded.getQueue(QStringLiteral("soundtrack")).size(), 1);
    const QFileInfo queueFile(data.filePath(QStringLiteral("local_queue.json")));
    QVERIFY(queueFile.permission(QFileDevice::ReadOwner));
    QVERIFY(queueFile.permission(QFileDevice::WriteOwner));
    QVERIFY(!queueFile.permission(QFileDevice::ReadGroup));
    QVERIFY(!queueFile.permission(QFileDevice::ReadOther));
}

void LocalFilesBackendTest::retainsFailedEntriesAndPreparesSelectedPlayback()
{
    QTemporaryDir app;
    QTemporaryDir data;
    QTemporaryDir media;
    QVERIFY(app.isValid() && data.isValid() && media.isValid());
    QVERIFY(writeLocalConfig(data.path(), media.path()));
    const QString first = media.filePath(QStringLiteral("first.mp4"));
    const QString second = media.filePath(QStringLiteral("second.mp4"));
    QVERIFY(writeFile(first));
    QVERIFY(writeFile(second));

    LocalFilesBackend backend(app.path(), data.path());
    QCOMPARE(backend.enqueue(QStringLiteral("media"),
                             {{QStringLiteral("filePath"), first}}), 1);
    QCOMPARE(backend.enqueue(QStringLiteral("media"),
                             {{QStringLiteral("filePath"), second}}), 1);
    const QVariantList queue = backend.getQueue(QStringLiteral("media"));
    const QString selectedId = queue.at(1).toMap().value(QStringLiteral("entryId")).toString();
    QVERIFY(backend.failQueueEntry(QStringLiteral("media"), selectedId,
                                   QStringLiteral("decoder failed\nretry")));

    const QVariantMap plan = backend.preparePlayback(selectedId, true);
    QVERIFY(!plan.value(QStringLiteral("playlistPath")).toString().isEmpty());
    QCOMPARE(plan.value(QStringLiteral("startIndex")).toInt(), 0);
    const QVariantList playbackEntries = plan.value(QStringLiteral("entries")).toList();
    QCOMPARE(playbackEntries.first().toMap().value(QStringLiteral("entryId")).toString(),
             selectedId);

    LocalFilesBackend reloaded(app.path(), data.path());
    const QVariantList persisted = reloaded.getQueue(QStringLiteral("media"));
    QCOMPARE(persisted.size(), 2);
    QCOMPARE(persisted.at(1).toMap().value(QStringLiteral("status")).toString(),
             QStringLiteral("failed"));
    QVERIFY(reloaded.resetQueueEntry(QStringLiteral("media"), selectedId));
    QCOMPARE(reloaded.getQueue(QStringLiteral("media")).at(1).toMap()
                 .value(QStringLiteral("status")).toString(), QStringLiteral("queued"));
}

void LocalFilesBackendTest::changingMediaRootPrunesOutOfRootQueueItems()
{
    QTemporaryDir app;
    QTemporaryDir data;
    QTemporaryDir firstRoot;
    QTemporaryDir secondRoot;
    QVERIFY(app.isValid() && data.isValid() && firstRoot.isValid() && secondRoot.isValid());
    QVERIFY(writeLocalConfig(data.path(), firstRoot.path()));
    const QString clip = firstRoot.filePath(QStringLiteral("clip.mp4"));
    QVERIFY(writeFile(clip));

    LocalFilesBackend backend(app.path(), data.path());
    QCOMPARE(backend.enqueue(QStringLiteral("media"),
                             {{QStringLiteral("filePath"), clip}}), 1);
    QSignalSpy queueSpy(&backend, &LocalFilesBackend::queueChanged);
    backend.setMediaRoot(secondRoot.path());
    QCOMPARE(backend.getQueue(QStringLiteral("media")).size(), 0);
    QVERIFY(queueSpy.size() >= 1);
}

void LocalFilesBackendTest::usesBundledMpvForSeparateAudio()
{
    QTemporaryDir root;
    QVERIFY(root.isValid());
    const QString appRoot = root.filePath(QStringLiteral("app"));
    const QString dataRoot = root.filePath(QStringLiteral("data"));
    const QString binDirectory = QDir(appRoot).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDirectory));
    QVERIFY(QDir().mkpath(dataRoot));
    QVERIFY(writeLocalConfig(dataRoot, root.path()));

    const QString markerPath = root.filePath(QStringLiteral("mpv-arguments.txt"));
    const QString fakeMpvPath = QDir(binDirectory).filePath(QStringLiteral("mpv"));
    const QByteArray script = QByteArrayLiteral("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"")
        + QFile::encodeName(markerPath) + QByteArrayLiteral("\"\n");
    QVERIFY(writeFile(fakeMpvPath, script));
    QVERIFY(QFile::setPermissions(fakeMpvPath, QFileDevice::ReadOwner |
                                  QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", QByteArray());
    const QString audioPath = root.filePath(QStringLiteral("separate audio.flac"));
    QVERIFY(writeFile(audioPath));
    LocalFilesBackend backend(appRoot, dataRoot);
    backend.startAudio({root.filePath(QStringLiteral("outside.mp3")), audioPath,
                        root.filePath(QStringLiteral("not-audio.txt"))});
    QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(markerPath), 3000);
    backend.stopAudio();
    if (originalPath.isNull())
        qunsetenv("PATH");
    else
        qputenv("PATH", originalPath);

    QFile marker(markerPath);
    QVERIFY(marker.open(QIODevice::ReadOnly | QIODevice::Text));
    const QStringList arguments = QString::fromUtf8(marker.readAll())
                                      .split('\n', Qt::SkipEmptyParts);
    QCOMPARE(arguments.value(0), audioPath);
    QVERIFY(arguments.contains(QStringLiteral("--no-video")));
    QVERIFY(arguments.contains(QStringLiteral("--loop-playlist=inf")));
    QVERIFY(arguments.contains(QStringLiteral("--no-terminal")));
    QVERIFY(arguments.contains(QStringLiteral("--really-quiet")));
}

QTEST_MAIN(LocalFilesBackendTest)
#include "LocalFilesBackendTest.moc"
