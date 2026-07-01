#include "LocalFilesBackend.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

static const QStringList kMediaExts = {
    "mp4", "mkv", "avi", "mov", "m4v", "webm", "wmv", "flv", "f4v", "mpg", "mpeg", "vob", "m3u", "m3u8"
};

static const QStringList kSidecarSubtitleExts = {
    "srt", "ass", "ssa", "sub", "vtt", "smi"
};

static QString streamTag(const QJsonObject &stream, const QString &key) {
    return stream["tags"].toObject()[key].toString().trimmed();
}

static QString streamLabel(const QJsonObject &stream, const QString &fallbackPrefix, int trackNumber) {
    const QString displayTitle = streamTag(stream, "title");
    const QString language = streamTag(stream, "language").toUpper();
    const QString codec = stream["codec_name"].toString().toUpper();
    const int channels = stream["channels"].toInt();

    QString label;
    if (!language.isEmpty() && !displayTitle.isEmpty())
        label = language + " - " + displayTitle;
    else if (!displayTitle.isEmpty())
        label = displayTitle;
    else if (!language.isEmpty())
        label = language;
    else
        label = QString("%1 %2").arg(fallbackPrefix).arg(trackNumber);

    QStringList details;
    if (!codec.isEmpty())
        details << codec;
    if (channels > 0)
        details << QString("%1CH").arg(channels);
    if (!details.isEmpty())
        label += " (" + details.join(", ") + ")";

    return label.toUpper();
}

static QString sidecarLabel(const QFileInfo &mediaInfo, const QFileInfo &subtitleInfo, int trackNumber) {
    QString stem = subtitleInfo.completeBaseName();
    const QString mediaStem = mediaInfo.completeBaseName();
    if (stem == mediaStem) {
        stem = QString("SUBTITLE %1").arg(trackNumber);
    } else if (stem.startsWith(mediaStem + ".")) {
        stem = stem.mid(mediaStem.length() + 1);
    }

    QString label = stem.trimmed().isEmpty() ? QString("SUBTITLE %1").arg(trackNumber) : stem.trimmed();
    label += QString(" (%1)").arg(subtitleInfo.suffix().toUpper());
    return label.toUpper();
}

static QString executablePathIfUsable(const QString &path) {
    const QFileInfo info(path);
    if (info.isFile() && info.isExecutable())
        return info.absoluteFilePath();
    return {};
}

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

LocalFilesBackend::LocalFilesBackend(const QString &appRoot, const QString &dataRoot, QObject *parent)
    : QObject(parent), m_appRoot(appRoot), m_dataRoot(dataRoot), m_mediaRoot(defaultMediaRoot())
{
    // Resolve the configured media directory (falls back to ~/Desktop).
    QFile f(m_dataRoot + "/config.json");
    if (f.open(QIODevice::ReadOnly)) {
        QJsonObject cfg = QJsonDocument::fromJson(f.readAll()).object();
        QString dir = cfg["modules"].toObject()["com.240mp.local_files"].toObject()
                          ["media_directory"].toString();
        if (!dir.isEmpty())
            setMediaRoot(dir);
    }
}

QString LocalFilesBackend::historyFilePath() const {
    return m_dataRoot + "/local_files_history.json";
}

QVariantMap LocalFilesBackend::loadHistory() const {
    QFile file(historyFilePath());
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}

void LocalFilesBackend::saveHistory(const QVariantMap &history) {
    QFile file(historyFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.write(QJsonDocument(QJsonObject::fromVariantMap(history)).toJson(QJsonDocument::Compact));
}

QVariantMap LocalFilesBackend::getSavedPosition(const QString &filePath) {
    const QVariant val = loadHistory().value(filePath);
    if (!val.isValid())
        return {};
    if (val.canConvert<QVariantMap>()) {
        QVariantMap entry = val.toMap();
        if (!entry.contains("plPos")) entry["plPos"] = -1;
        return entry;
    }
    // Legacy: plain int stored (pos only)
    return {{"pos", val.toInt()}, {"plPos", -1}};
}

void LocalFilesBackend::savePosition(const QString &filePath, int positionMs, int playlistPos) {
    QVariantMap history = loadHistory();
    QVariantMap entry;
    entry["pos"]   = positionMs;
    entry["plPos"] = playlistPos;
    history[filePath] = entry;
    saveHistory(history);
}

void LocalFilesBackend::clearPosition(const QString &filePath) {
    QVariantMap history = loadHistory();
    history.remove(filePath);
    saveHistory(history);
}

QVariantMap LocalFilesBackend::probeMediaTracks(const QString &filePath) {
    QVariantMap result;
    QVariantList audioStreams;
    QVariantList subtitleStreams;
    result["audioStreams"] = audioStreams;
    result["subtitleStreams"] = subtitleStreams;

    const QFileInfo mediaInfo(filePath);
    const QString canonicalFile = mediaInfo.canonicalFilePath();
    const QString canonicalRoot = QDir(m_mediaRoot).canonicalPath();
    if (canonicalFile.isEmpty() || canonicalRoot.isEmpty() ||
        (canonicalFile != canonicalRoot && !canonicalFile.startsWith(canonicalRoot + "/"))) {
        qWarning("[LocalFiles] track probe path escapes media root: %s", qPrintable(filePath));
        return result;
    }

    QString ffprobe = executablePathIfUsable(QDir(m_appRoot).filePath("bin/ffprobe"));
#ifdef Q_OS_MACOS
    if (ffprobe.isEmpty()) {
        const QDir appDir(QCoreApplication::applicationDirPath());
        ffprobe = executablePathIfUsable(appDir.filePath("../Resources/bin/ffprobe"));
    }
#endif
    if (ffprobe.isEmpty())
        ffprobe = QStandardPaths::findExecutable("ffprobe");
#ifdef Q_OS_MACOS
    if (ffprobe.isEmpty())
        ffprobe = QStandardPaths::findExecutable("ffprobe", {"/opt/homebrew/bin", "/usr/local/bin"});
#endif
    if (ffprobe.isEmpty()) {
        qWarning("[LocalFiles] ffprobe not found in app bundle or PATH; track selection unavailable for %s",
                 qPrintable(filePath));
        return result;
    }

    QProcess proc;
    proc.start(ffprobe, {"-v", "error", "-print_format", "json", "-show_streams", filePath});
    if (!proc.waitForStarted(3000)) {
        qWarning("[LocalFiles] ffprobe could not start for %s", qPrintable(filePath));
        return result;
    }
    if (!proc.waitForFinished(10000)) {
        proc.kill();
        proc.waitForFinished(1000);
        qWarning("[LocalFiles] ffprobe timed out for %s", qPrintable(filePath));
        return result;
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        qWarning("[LocalFiles] ffprobe failed for %s: %s",
                 qPrintable(filePath),
                 qPrintable(QString::fromUtf8(proc.readAllStandardError()).trimmed()));
        return result;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(proc.readAllStandardOutput(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning("[LocalFiles] ffprobe returned invalid JSON for %s", qPrintable(filePath));
        return result;
    }

    int audioTrack = 0;
    int embeddedSubtitleTrack = 0;
    const QJsonArray streams = doc.object()["streams"].toArray();
    for (const QJsonValue &value : streams) {
        const QJsonObject stream = value.toObject();
        const QString codecType = stream["codec_type"].toString();
        if (codecType == "audio") {
            ++audioTrack;
            audioStreams.append(QVariantMap{
                {"id", audioTrack},
                {"mpvTrack", audioTrack},
                {"displayTitle", streamLabel(stream, "AUDIO", audioTrack)}
            });
        } else if (codecType == "subtitle") {
            ++embeddedSubtitleTrack;
            subtitleStreams.append(QVariantMap{
                {"id", embeddedSubtitleTrack},
                {"mpvTrack", embeddedSubtitleTrack},
                {"displayTitle", streamLabel(stream, "SUBTITLE", embeddedSubtitleTrack)},
                {"subFile", ""}
            });
        }
    }

    const QDir mediaDir(mediaInfo.absolutePath());
    int sidecarTrack = embeddedSubtitleTrack;
    for (const QString &name : mediaDir.entryList(QDir::Files, QDir::Name)) {
        const QFileInfo subtitleInfo(mediaDir.absoluteFilePath(name));
        if (!kSidecarSubtitleExts.contains(subtitleInfo.suffix().toLower()))
            continue;

        const QString subtitleStem = subtitleInfo.completeBaseName();
        const QString mediaStem = mediaInfo.completeBaseName();
        if (subtitleStem != mediaStem && !subtitleStem.startsWith(mediaStem + "."))
            continue;

        ++sidecarTrack;
        subtitleStreams.append(QVariantMap{
            {"id", sidecarTrack},
            {"mpvTrack", 0},
            {"displayTitle", sidecarLabel(mediaInfo, subtitleInfo, sidecarTrack)},
            {"subFile", subtitleInfo.absoluteFilePath()}
        });
    }

    result["audioStreams"] = audioStreams;
    result["subtitleStreams"] = subtitleStreams;
    return result;
}

void LocalFilesBackend::get_resume_playback_options() {
    QVariantList options;
    QVariantMap ask; ask["id"] = "ask"; ask["label"] = "Ask";
    QVariantMap yes; yes["id"] = "yes"; yes["label"] = "Always";
    QVariantMap no;  no["id"]  = "no";  no["label"]  = "Never";
    options << ask << yes << no;
    emit dynamicOptionsReady("resume_playback", options);
}

QString LocalFilesBackend::mediaRoot() const {
    return m_mediaRoot;
}

void LocalFilesBackend::setMediaRoot(const QString &path) {
    m_mediaRoot = expandedMediaRoot(path);
    QDir().mkpath(m_mediaRoot);
    qDebug("[LocalFiles] media root: %s", qPrintable(m_mediaRoot));
}

void LocalFilesBackend::onSettingChanged(const QString &moduleId, const QString &key, const QVariant &value) {
    if (moduleId == QLatin1String("com.240mp.local_files") && key == QLatin1String("media_directory"))
        setMediaRoot(value.toString());
}

QVariantList LocalFilesBackend::getItems(const QString &path) {
    QVariantList result;
    QDir dir(path);
    if (!dir.exists()) {
        qWarning("[LocalFiles] directory not found: %s", qPrintable(path));
        return result;
    }
    QString canonical = QDir(path).canonicalPath();
    QString root      = QDir(m_mediaRoot).canonicalPath();
    if (!canonical.startsWith(root)) {
        qWarning("[LocalFiles] path escapes media root: %s", qPrintable(path));
        return result;
    }

    static const QStringList kPlaylistExts = { "m3u", "m3u8" };
    for (const QString &name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        QString suffix = QFileInfo(name).suffix().toLower();
        if (kPlaylistExts.contains(suffix)) {
            QString innerPath = dir.absoluteFilePath(name) + "/" + name;
            if (QFileInfo::exists(innerPath)) {
                QVariantMap item;
                item["name"]     = name;
                item["path"]     = innerPath;
                item["isFolder"] = false;
                result.append(item);
                continue;
            }
        }
        QVariantMap item;
        item["name"]     = name;
        item["path"]     = dir.absoluteFilePath(name);
        item["isFolder"] = true;
        result.append(item);
    }

    for (const QString &name : dir.entryList(QDir::Files, QDir::Name)) {
        if (!kMediaExts.contains(QFileInfo(name).suffix().toLower())) continue;
        QVariantMap item;
        item["name"]     = name;
        item["path"]     = dir.absoluteFilePath(name);
        item["isFolder"] = false;
        result.append(item);
    }
    return result;
}
