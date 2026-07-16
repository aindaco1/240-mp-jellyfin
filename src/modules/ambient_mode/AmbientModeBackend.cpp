#include "AmbientModeBackend.h"
#include "tools/HelperResolver.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

static const QStringList kVideoExts = {
    "mp4", "mkv", "avi", "mov", "m4v", "webm", "wmv", "flv", "f4v", "mpg", "mpeg", "vob"
};
static const QStringList kAudioExts = {
    "mp3", "wav", "flac", "m4a", "m3u", "ogg", "aac", "m3u8"
};

static QString defaultMediaRoot()
{
    return QDir::home().filePath("Desktop");
}

static QString expandedMediaRoot(const QString &path)
{
    if (path.isEmpty())
        return defaultMediaRoot();
    if (path == "~")
        return QDir::homePath();
    if (path.startsWith("~/"))
        return QDir::home().filePath(path.mid(2));
    return path;
}

AmbientModeBackend::AmbientModeBackend(const QString &appRoot, const QString &dataRoot,
                                       QObject *parent)
    : QObject(parent), m_appRoot(appRoot), m_dataRoot(dataRoot),
      m_mediaRoot(defaultMediaRoot())
{
    // Resolve the configured media directory (falls back to ~/Desktop).
    QFile f(m_dataRoot + "/config.json");
    if (f.open(QIODevice::ReadOnly)) {
        QJsonObject cfg = QJsonDocument::fromJson(f.readAll()).object();
        QString dir = cfg["modules"].toObject()["com.240mp.ambient_mode"].toObject()
                          ["media_directory"].toString();
        if (!dir.isEmpty())
            setMediaRoot(dir);
    }
}

AmbientModeBackend::~AmbientModeBackend()
{
    stopAudio();
}

QString AmbientModeBackend::mediaRoot() const
{
    return m_mediaRoot;
}

void AmbientModeBackend::setMediaRoot(const QString &path)
{
    m_mediaRoot = expandedMediaRoot(path);
    QDir().mkpath(m_mediaRoot);
    qDebug("[AmbientMode] media root: %s", qPrintable(m_mediaRoot));
}

QVariantList AmbientModeBackend::scanFiles(const QStringList &extensions) const
{
    QVariantList result;
    QDir dir(m_mediaRoot);
    if (!dir.exists())
        return result;
    for (const QString &name : dir.entryList(QDir::Files, QDir::Name)) {
        if (!extensions.contains(QFileInfo(name).suffix().toLower()))
            continue;
        QVariantMap item;
        item["name"] = name;
        item["path"] = dir.absoluteFilePath(name);
        result.append(item);
    }
    return result;
}

QVariantList AmbientModeBackend::getVideoFiles() const
{
    return scanFiles(kVideoExts);
}

QVariantList AmbientModeBackend::getAudioFiles() const
{
    return scanFiles(kAudioExts);
}

void AmbientModeBackend::startAudio(const QString &path)
{
    stopAudio();

    const QString bin = HelperResolver::mpv(m_appRoot);
    if (bin.isEmpty()) {
        qWarning("[AmbientMode] mpv not found in app bundle or PATH — audio will not play");
        return;
    }

    QStringList args;
    args << path
         << QStringLiteral("--no-video")
         << QStringLiteral("--loop-playlist=inf")
         << QStringLiteral("--no-terminal")
         << QStringLiteral("--really-quiet");

    m_audioProcess = new QProcess(this);
    m_audioProcess->setProcessEnvironment(HelperResolver::processEnvironment(m_appRoot));
    m_audioProcess->start(bin, args);
    qDebug("[AmbientMode] audio process started: %s", qPrintable(path));
}

void AmbientModeBackend::stopAudio()
{
    if (!m_audioProcess)
        return;
    if (m_audioProcess->state() != QProcess::NotRunning) {
        m_audioProcess->terminate();
        m_audioProcess->waitForFinished(1000);
    }
    m_audioProcess->deleteLater();
    m_audioProcess = nullptr;
    qDebug("[AmbientMode] audio process stopped");
}

void AmbientModeBackend::onSettingChanged(const QString &moduleId, const QString &key, const QVariant &value)
{
    if (moduleId == QLatin1String("com.240mp.ambient_mode") && key == QLatin1String("media_directory"))
        setMediaRoot(value.toString());
}
