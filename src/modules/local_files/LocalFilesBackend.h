#pragma once

#include <QObject>
#include <QProcess>
#include <QSet>
#include <QVariantList>
#include <QVariantMap>

class LocalFilesBackend final : public QObject {
    Q_OBJECT

public:
    explicit LocalFilesBackend(const QString &appRoot, const QString &dataRoot,
                               QObject *parent = nullptr);
    ~LocalFilesBackend() override;

    Q_INVOKABLE QVariantList getItems(const QString &path);
    Q_INVOKABLE QString mediaRoot() const;
    Q_INVOKABLE void setMediaRoot(const QString &path);
    Q_INVOKABLE bool isImage(const QString &path) const;
    Q_INVOKABLE bool isAudio(const QString &path) const;
    Q_INVOKABLE bool isPlaylist(const QString &path) const;
    Q_INVOKABLE bool playlistContainsImages(const QString &path) const;

    Q_INVOKABLE QVariantMap getSavedPosition(const QString &filePath);
    Q_INVOKABLE void savePosition(const QString &filePath, int positionMs, int playlistPos);
    Q_INVOKABLE void clearPosition(const QString &filePath);
    Q_INVOKABLE QVariantMap probeMediaTracks(const QString &filePath);

    // Both persistent queues share one validated and atomically-written store.
    Q_INVOKABLE QVariantList getQueue(const QString &kind = QStringLiteral("media")) const;
    Q_INVOKABLE int enqueue(const QString &kind, const QVariantMap &candidate);
    Q_INVOKABLE bool removeQueueEntry(const QString &kind, const QString &entryId);
    Q_INVOKABLE bool moveQueueEntry(const QString &kind, int fromIndex, int toIndex);
    Q_INVOKABLE void clearQueue(const QString &kind);
    Q_INVOKABLE bool failQueueEntry(const QString &kind, const QString &entryId,
                                    const QString &message);
    Q_INVOKABLE bool resetQueueEntry(const QString &kind, const QString &entryId);
    Q_INVOKABLE QVariantMap preparePlayback(const QString &startEntryId,
                                            bool shuffle = false);
    Q_INVOKABLE QStringList soundtrackPaths(bool shuffle = false) const;

    Q_INVOKABLE void startAudio(const QStringList &paths, bool shuffle = false);
    Q_INVOKABLE void stopAudio();

    Q_INVOKABLE void get_repeat_mode_options();
    Q_INVOKABLE void get_resume_playback_options();
    Q_INVOKABLE void get_shuffle_playback_options();
    Q_INVOKABLE void get_auto_subtitles_options();
    Q_INVOKABLE void get_subtitle_languages();
    Q_INVOKABLE void get_image_duration_options();

signals:
    void dynamicOptionsReady(const QString &key, const QVariant &options);
    void queueChanged(const QString &kind, const QVariant &items);

public slots:
    void onSettingChanged(const QString &moduleId, const QString &key,
                          const QVariant &value);

private slots:
    void onAudioProcessFinished();

private:
    static constexpr int kQueueSchemaVersion = 1;
    static constexpr int kMaxQueueEntries = 1000;
    static constexpr int kMaxPlaylistDepth = 8;

    QString historyFilePath() const;
    QString queueFilePath() const;
    QString playbackPlaylistFilePath() const;
    QVariantMap loadHistory() const;
    void saveHistory(const QVariantMap &history);
    bool isPathWithinMediaRoot(const QString &path) const;
    bool queueKindAcceptsPath(const QString &kind, const QString &path) const;
    bool isValidQueueKind(const QString &kind) const;

    QVariantList &mutableQueue(const QString &kind);
    const QVariantList &queue(const QString &kind) const;
    int queueIndexForEntryId(const QString &kind, const QString &entryId) const;
    QVariantMap validatedQueueEntry(const QString &kind, const QVariantMap &candidate,
                                    bool createEntryId, bool requireFile) const;
    QStringList expandedPlaylistEntries(const QString &playlistPath,
                                        const QString &kind,
                                        QSet<QString> &visited,
                                        int depth) const;
    void loadQueues();
    bool saveQueues() const;
    bool publishQueues(const QString &changedKind);
    void pruneQueuesForMediaRoot();
    QString writePlaybackPlaylist(const QVariantList &entries) const;

    void launchAudioProcess();

    QString m_appRoot;
    QString m_dataRoot;
    QString m_mediaRoot;
    QVariantList m_mediaQueue;
    QVariantList m_soundtrackQueue;

    QProcess *m_audioProcess = nullptr;
    QStringList m_audioPaths;
    bool m_audioShuffle = false;
    bool m_audioStopRequested = true;
    int m_audioRespawnCount = 0;
    quint64 m_audioGeneration = 0;
};
