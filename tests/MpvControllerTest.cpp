#include "player/MpvController.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

namespace {

bool writeExecutable(const QString &path, const QByteArray &contents)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    if (file.write(contents) != contents.size())
        return false;
    file.close();
    return file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                               QFileDevice::ExeOwner);
}

}

class MpvControllerTest final : public QObject {
    Q_OBJECT

private slots:
    void youtubeModesValidateFormats_data();
    void youtubeModesValidateFormats();
    void repeatModesUseNarrowMpvArguments_data();
    void repeatModesUseNarrowMpvArguments();
    void muteAudioUsesNoAudioArgument();
};

void MpvControllerTest::youtubeModesValidateFormats_data()
{
    QTest::addColumn<QString>("oscMode");
    QTest::addColumn<QString>("modeArgument");

    QTest::newRow("karaoke") << QStringLiteral("karaoke")
                              << QStringLiteral("--script-opts-append=karaoke=1");
    QTest::newRow("retro") << QStringLiteral("retro")
                            << QStringLiteral("--script-opts-append=retro-tv=1");
}

void MpvControllerTest::youtubeModesValidateFormats()
{
    QFETCH(QString, oscMode);
    QFETCH(QString, modeArgument);

    QTemporaryDir root;
    QVERIFY(root.isValid());

    const QString appRoot = root.filePath(QStringLiteral("app"));
    const QString binDirectory = QDir(appRoot).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDirectory));

    const QString markerPath = root.filePath(QStringLiteral("mpv-arguments.txt"));
    const QString fakeMpvPath = QDir(binDirectory).filePath(QStringLiteral("mpv"));
    const QByteArray fakeMpv = QByteArrayLiteral("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"")
                             + QFile::encodeName(markerPath)
                             + QByteArrayLiteral("\"\n");
    QVERIFY(writeExecutable(fakeMpvPath, fakeMpv));

    const QString fakeYtDlpPath = QDir(binDirectory).filePath(QStringLiteral("yt-dlp"));
    const QString fakeDenoPath = QDir(binDirectory).filePath(QStringLiteral("deno"));
    QVERIFY(writeExecutable(fakeYtDlpPath, QByteArrayLiteral("#!/bin/sh\nexit 0\n")));
    QVERIFY(writeExecutable(fakeDenoPath, QByteArrayLiteral("#!/bin/sh\nexit 0\n")));

    MpvController controller(appRoot);
    controller.setPlaybackScreenIndex(1);
    controller.loadAndPlay(QStringLiteral("https://www.youtube.com/watch?v=abcdefghijk"),
                           0.0f, 0, -1, QStringList{}, false, -1, 0.0f,
                           QString{}, false, oscMode);

    QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(markerPath), 3000);

    QFile marker(markerPath);
    QVERIFY(marker.open(QIODevice::ReadOnly | QIODevice::Text));
    const QStringList arguments = QString::fromUtf8(marker.readAll())
                                      .split('\n', Qt::SkipEmptyParts);

    QVERIFY(arguments.contains(modeArgument));
    QVERIFY(arguments.contains(QStringLiteral("--screen=1")));
    QVERIFY(arguments.contains(QStringLiteral("--fs-screen=1")));
    QVERIFY(arguments.contains(QStringLiteral(
        "--ytdl-raw-options-append=check-formats=")));
    QVERIFY(arguments.contains(QStringLiteral(
        "--script-opts-append=ytdl_hook-ytdl_path=") + fakeYtDlpPath));
    QVERIFY(arguments.contains(QStringLiteral(
        "--ytdl-raw-options-append=js-runtimes=deno:") + fakeDenoPath));
}

void MpvControllerTest::repeatModesUseNarrowMpvArguments_data()
{
    QTest::addColumn<QString>("repeatMode");
    QTest::addColumn<QString>("expectedArgument");
    QTest::newRow("queue") << QStringLiteral("queue") << QStringLiteral("--loop-playlist=inf");
    QTest::newRow("one") << QStringLiteral("one") << QStringLiteral("--loop-file=inf");
}

void MpvControllerTest::repeatModesUseNarrowMpvArguments()
{
    QFETCH(QString, repeatMode);
    QFETCH(QString, expectedArgument);
    QTemporaryDir root;
    QVERIFY(root.isValid());
    const QString appRoot = root.filePath(QStringLiteral("app"));
    const QString binDirectory = QDir(appRoot).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDirectory));
    const QString markerPath = root.filePath(QStringLiteral("mpv-arguments.txt"));
    const QByteArray fakeMpv = QByteArrayLiteral("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"")
        + QFile::encodeName(markerPath) + QByteArrayLiteral("\"\n");
    QVERIFY(writeExecutable(QDir(binDirectory).filePath(QStringLiteral("mpv")), fakeMpv));

    MpvController controller(appRoot);
    controller.loadAndPlayWithOptions(QStringLiteral("/tmp/local-queue.m3u8"),
                                      {{QStringLiteral("repeatMode"), repeatMode}});
    QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(markerPath), 3000);
    QFile marker(markerPath);
    QVERIFY(marker.open(QIODevice::ReadOnly | QIODevice::Text));
    const QStringList arguments = QString::fromUtf8(marker.readAll())
                                      .split('\n', Qt::SkipEmptyParts);
    QVERIFY(arguments.contains(expectedArgument));
    if (repeatMode == QLatin1String("one"))
        QVERIFY(!arguments.contains(QStringLiteral("--loop-playlist=inf")));
}

void MpvControllerTest::muteAudioUsesNoAudioArgument()
{
    QTemporaryDir root;
    QVERIFY(root.isValid());
    const QString appRoot = root.filePath(QStringLiteral("app"));
    const QString binDirectory = QDir(appRoot).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDirectory));
    const QString markerPath = root.filePath(QStringLiteral("mpv-arguments.txt"));
    const QByteArray fakeMpv = QByteArrayLiteral("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"")
        + QFile::encodeName(markerPath) + QByteArrayLiteral("\"\n");
    QVERIFY(writeExecutable(QDir(binDirectory).filePath(QStringLiteral("mpv")), fakeMpv));

    MpvController controller(appRoot);
    controller.loadAndPlayWithOptions(QStringLiteral("/tmp/local-queue.m3u8"),
                                      {{QStringLiteral("muteAudio"), true}});
    QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(markerPath), 3000);
    QFile marker(markerPath);
    QVERIFY(marker.open(QIODevice::ReadOnly | QIODevice::Text));
    const QStringList arguments = QString::fromUtf8(marker.readAll())
                                      .split('\n', Qt::SkipEmptyParts);
    QVERIFY(arguments.contains(QStringLiteral("--no-audio")));
}

QTEST_GUILESS_MAIN(MpvControllerTest)
#include "MpvControllerTest.moc"
