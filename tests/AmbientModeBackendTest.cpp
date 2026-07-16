#include "modules/ambient_mode/AmbientModeBackend.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

class AmbientModeBackendTest : public QObject {
    Q_OBJECT

private slots:
    void usesBundledMpvForSeparateAudio();
};

void AmbientModeBackendTest::usesBundledMpvForSeparateAudio()
{
    QTemporaryDir root;
    QVERIFY(root.isValid());

    const QString appRoot = root.filePath(QStringLiteral("app"));
    const QString dataRoot = root.filePath(QStringLiteral("data"));
    const QString binDirectory = QDir(appRoot).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(binDirectory));
    QVERIFY(QDir().mkpath(dataRoot));

    const QString markerPath = root.filePath(QStringLiteral("mpv-arguments.txt"));
    const QString fakeMpvPath = QDir(binDirectory).filePath(QStringLiteral("mpv"));
    QFile fakeMpv(fakeMpvPath);
    QVERIFY(fakeMpv.open(QIODevice::WriteOnly | QIODevice::Text));
    fakeMpv.write("#!/bin/sh\n");
    fakeMpv.write("printf '%s\\n' \"$@\" > ");
    fakeMpv.write(QFile::encodeName(QStringLiteral("\"") + markerPath + QStringLiteral("\"")));
    fakeMpv.write("\n");
    fakeMpv.close();
    QVERIFY(fakeMpv.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                                   QFileDevice::ExeOwner));

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", QByteArray());

    AmbientModeBackend backend(appRoot, dataRoot);
    const QString audioPath = root.filePath(QStringLiteral("separate audio.flac"));
    backend.startAudio(audioPath);
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

QTEST_MAIN(AmbientModeBackendTest)
#include "AmbientModeBackendTest.moc"
