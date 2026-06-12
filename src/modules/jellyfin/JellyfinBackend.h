#pragma once

#include <QHash>
#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QVariant>

class JellyfinBackend : public QObject {
    Q_OBJECT
public:
    explicit JellyfinBackend(const QString &appRoot, const QString &dataRoot, QObject *parent = nullptr);

    Q_INVOKABLE QString get_auth_state();
    Q_INVOKABLE QString get_active_user_name();
    Q_INVOKABLE QString get_active_server_name();
    Q_INVOKABLE QString get_last_server_url();

    Q_INVOKABLE void authenticate(const QString &serverUrl, const QString &username, const QString &password);
    Q_INVOKABLE void start_quick_connect(const QString &serverUrl);
    Q_INVOKABLE void cancel_quick_connect();
    Q_INVOKABLE void logout();

    Q_INVOKABLE void load_libraries();
    Q_INVOKABLE void load_items(const QString &libraryId);
    Q_INVOKABLE void load_item_detail(const QString &itemId);
    Q_INVOKABLE void build_stream_url(const QString &itemId, const QString &mediaSourceId = QString());

    Q_INVOKABLE void getVideoQualities();
    Q_INVOKABLE void get_resume_playback_options();

signals:
    void authSuccess();
    void quickConnectCodeReady(const QString &code);
    void logoutComplete();
    void authStateChanged();
    void librariesLoaded(const QVariant &libraries);
    void itemsLoaded(const QVariant &items);
    void itemsPageLoaded(const QVariant &items, bool reset, bool finished);
    void itemLoaded(const QVariant &detail);
    void streamUrlReady(const QString &url, const QVariant &httpHeaders);
    void dynamicOptionsReady(const QString &key, const QVariant &options);
    void errorOccurred(const QString &message);

private:
    QJsonObject loadAuth() const;
    void saveAuth(const QJsonObject &auth) const;
    QString authFilePath() const;
    QString deviceId() const;

    QString normalizedServerUrl(const QString &serverUrl) const;
    QString serverUrl() const;
    QString accessToken() const;
    QString userId() const;
    QString authorizationValue(const QString &token) const;

    QNetworkRequest jellyfinRequest(const QUrl &url, const QString &token = QString(),
                                    bool includeSavedToken = true) const;
    QNetworkReply *jellyfinGet(const QUrl &url);
    QNetworkReply *jellyfinPostJson(const QUrl &url, const QByteArray &body,
                                     const QString &token = QString(),
                                     bool includeSavedToken = true);

    void handleAuthFailure(const QString &message);
    bool saveAuthenticationResult(const QJsonObject &result, const QString &baseUrl);
    void pollQuickConnect();
    void authenticateWithQuickConnectSecret();
    void load_items_page(const QString &libraryId, int startIndex, int generation);
    QVariantMap formatLibrary(const QJsonObject &item) const;
    QVariantMap formatItem(const QJsonObject &item) const;
    static int ticksToMs(qint64 ticks);
    static QString itemTitle(const QJsonObject &item);

    QString m_dataRoot;
    QNetworkAccessManager *m_nam;
    QTimer *m_quickConnectTimer;
    QString m_quickConnectServerUrl;
    QString m_quickConnectSecret;
    int m_itemsLoadGeneration = 0;
    QVariantList m_itemsLoadAccumulator;
    QHash<QString, QVariantList> m_itemCache;
};
