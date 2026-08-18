#pragma once

#include <QDateTime>
#include <QElapsedTimer>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class QJsonObject;
class QNetworkReply;
class NatureBackendTest;

class NatureBackend final : public QObject {
    Q_OBJECT

public:
    explicit NatureBackend(const QString &dataRoot, QObject *parent = nullptr);
    NatureBackend(const QString &dataRoot, const QUrl &apiEndpoint, QObject *parent = nullptr);

    Q_INVOKABLE void loadLatestObservations();
    Q_INVOKABLE void refreshObservations();

signals:
    void refreshStarted(bool hasCachedObservations);
    void observationsLoaded(const QVariantList &observations,
                            bool fromCache,
                            bool stale);
    void loadFailed(const QString &message, bool hasCachedObservations);

private:
    friend class NatureBackendTest;

    void beginRefresh(bool hasCachedObservations);
    void handleReply(QNetworkReply *reply);
    QUrl requestUrl() const;
    QVariantList observationsFromPayload(const QByteArray &payload, QString *error) const;
    QVariantMap itemFromObservation(const QJsonObject &observation) const;
    QUrl largePhotoUrl(const QString &url, const QString &licenseCode) const;
    QVariantMap validatedCachedItem(const QJsonObject &object) const;
    QVariantMap locationFromPlaceGuess(const QString &placeGuess) const;
    bool readCache(QVariantList *observations, QDateTime *fetchedAt) const;
    bool writeCache(const QVariantList &observations, const QDateTime &fetchedAt) const;
    bool cacheIsFresh(const QDateTime &fetchedAt) const;

    QNetworkAccessManager *m_network;
    QPointer<QNetworkReply> m_activeReply;
    QUrl m_apiEndpoint;
    QString m_dataRoot;
    QString m_cachePath;
    QVariantList m_lastObservations;
    QElapsedTimer m_lastRequestStarted;
    bool m_refreshQueued = false;
    bool m_queuedRefreshHasCache = false;
};
