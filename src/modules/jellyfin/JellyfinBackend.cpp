#include "JellyfinBackend.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QNetworkRequest>
#include <QSysInfo>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>
#include <QVariantList>
#include <QVariantMap>
#include <QDebug>

static constexpr int kItemsPageSize = 250;

JellyfinBackend::JellyfinBackend(const QString &appRoot, const QString &dataRoot, QObject *parent)
    : QObject(parent)
    , m_dataRoot(dataRoot)
    , m_nam(new QNetworkAccessManager(this))
    , m_quickConnectTimer(new QTimer(this))
{
    Q_UNUSED(appRoot);
    m_quickConnectTimer->setInterval(2000);
    connect(m_quickConnectTimer, &QTimer::timeout, this, &JellyfinBackend::pollQuickConnect);
}

QString JellyfinBackend::authFilePath() const {
    return m_dataRoot + "/jellyfin_auth.json";
}

QJsonObject JellyfinBackend::loadAuth() const {
    QFile f(authFilePath());
    if (!f.open(QIODevice::ReadOnly))
        return {};

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return {};

    return doc.object();
}

void JellyfinBackend::saveAuth(const QJsonObject &auth) const {
    QFile f(authFilePath());
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning("[JellyfinBackend] Could not write jellyfin_auth.json: %s", qPrintable(f.errorString()));
        return;
    }
    f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    f.write(QJsonDocument(auth).toJson(QJsonDocument::Indented));
    f.close();
    QFile::setPermissions(authFilePath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

QString JellyfinBackend::normalizedServerUrl(const QString &serverUrl) const {
    QString trimmed = serverUrl.trimmed();
    while (trimmed.endsWith('/'))
        trimmed.chop(1);
    if (!trimmed.isEmpty() && !trimmed.startsWith("http://") && !trimmed.startsWith("https://"))
        trimmed.prepend("https://");
    return trimmed;
}

QString JellyfinBackend::serverUrl() const {
    return loadAuth()["serverUrl"].toString();
}

QString JellyfinBackend::accessToken() const {
    return loadAuth()["accessToken"].toString();
}

QString JellyfinBackend::userId() const {
    return loadAuth()["userId"].toString();
}

QString JellyfinBackend::deviceId() const {
    QJsonObject auth = loadAuth();
    QString existing = auth["deviceId"].toString();
    if (!existing.isEmpty())
        return existing;

    QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    auth["deviceId"] = id;
    saveAuth(auth);
    return id;
}

QString JellyfinBackend::authorizationValue(const QString &token) const {
    QStringList parts;
    parts << "MediaBrowser Client=\"240-mp-jellyfin\"";
    parts << QString("Device=\"%1\"").arg(QSysInfo::prettyProductName().isEmpty()
                                             ? QStringLiteral("macOS")
                                             : QSysInfo::prettyProductName());
    parts << QString("DeviceId=\"%1\"").arg(deviceId());
    parts << "Version=\"1.0\"";
    if (!token.isEmpty())
        parts << QString("Token=\"%1\"").arg(token);
    return parts.join(", ");
}

QNetworkRequest JellyfinBackend::jellyfinRequest(const QUrl &url, const QString &token,
                                                 bool includeSavedToken) const {
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");

    const QString effectiveToken = token.isEmpty() && includeSavedToken ? accessToken() : token;
    const QString authValue = authorizationValue(effectiveToken);
    req.setRawHeader("Authorization", authValue.toUtf8());
    req.setRawHeader("X-Emby-Authorization", authValue.toUtf8());
    return req;
}

QNetworkReply *JellyfinBackend::jellyfinGet(const QUrl &url) {
    return m_nam->get(jellyfinRequest(url));
}

QNetworkReply *JellyfinBackend::jellyfinPostJson(const QUrl &url, const QByteArray &body,
                                                 const QString &token, bool includeSavedToken) {
    return m_nam->post(jellyfinRequest(url, token, includeSavedToken), body);
}

QString JellyfinBackend::get_auth_state() {
    QJsonObject auth = loadAuth();
    return (!auth["serverUrl"].toString().isEmpty() &&
            !auth["accessToken"].toString().isEmpty() &&
            !auth["userId"].toString().isEmpty())
        ? QStringLiteral("authed")
        : QStringLiteral("unauthenticated");
}

QString JellyfinBackend::get_active_user_name() {
    return loadAuth()["username"].toString();
}

QString JellyfinBackend::get_active_server_name() {
    const QJsonObject auth = loadAuth();
    QString name = auth["serverName"].toString();
    return name.isEmpty() ? auth["serverUrl"].toString() : name;
}

QString JellyfinBackend::get_last_server_url() {
    return loadAuth()["serverUrl"].toString();
}

void JellyfinBackend::authenticate(const QString &serverUrlInput, const QString &username, const QString &password) {
    cancel_quick_connect();

    const QString base = normalizedServerUrl(serverUrlInput);
    if (base.isEmpty() || username.trimmed().isEmpty() || password.isEmpty()) {
        emit errorOccurred("Server URL, username, and password are required.");
        return;
    }

    QJsonObject existing = loadAuth();
    if (existing["deviceId"].toString().isEmpty()) {
        existing["deviceId"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
        saveAuth(existing);
    }

    QJsonObject body;
    body["Username"] = username.trimmed();
    body["Pw"] = password;

    QNetworkReply *reply = jellyfinPostJson(QUrl(base + "/Users/AuthenticateByName"),
                                            QJsonDocument(body).toJson(QJsonDocument::Compact),
                                            QString(),
                                            false);
    connect(reply, &QNetworkReply::finished, this, [this, reply, base]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit errorOccurred(QString("Jellyfin sign-in failed (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred("Jellyfin sign-in returned an invalid response.");
            return;
        }

        if (!saveAuthenticationResult(doc.object(), base)) {
            emit errorOccurred("Jellyfin sign-in did not return a usable access token.");
            return;
        }

        emit authSuccess();
        emit authStateChanged();
    });
}

void JellyfinBackend::start_quick_connect(const QString &serverUrlInput) {
    cancel_quick_connect();

    const QString base = normalizedServerUrl(serverUrlInput);
    if (base.isEmpty()) {
        emit errorOccurred("Server URL is required for Quick Connect.");
        return;
    }

    QJsonObject existing = loadAuth();
    if (existing["deviceId"].toString().isEmpty()) {
        existing["deviceId"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
        saveAuth(existing);
    }

    QNetworkReply *reply = jellyfinPostJson(QUrl(base + "/QuickConnect/Initiate"),
                                            QByteArray{},
                                            QString(),
                                            false);
    connect(reply, &QNetworkReply::finished, this, [this, reply, base]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit errorOccurred(QString("Quick Connect could not start (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred("Quick Connect returned an invalid response.");
            return;
        }

        const QJsonObject result = doc.object();
        m_quickConnectSecret = result["Secret"].toString();
        const QString code = result["Code"].toString();
        if (m_quickConnectSecret.isEmpty() || code.isEmpty()) {
            emit errorOccurred("Quick Connect did not return a usable code.");
            return;
        }

        m_quickConnectServerUrl = base;
        emit quickConnectCodeReady(code);
        m_quickConnectTimer->start();
    });
}

void JellyfinBackend::cancel_quick_connect() {
    m_quickConnectTimer->stop();
    m_quickConnectServerUrl.clear();
    m_quickConnectSecret.clear();
}

void JellyfinBackend::logout() {
    cancel_quick_connect();
    ++m_itemsLoadGeneration;
    m_itemsLoadAccumulator.clear();
    m_itemCache.clear();
    QFile::remove(authFilePath());
    emit logoutComplete();
    emit authStateChanged();
}

void JellyfinBackend::handleAuthFailure(const QString &message) {
    emit errorOccurred(message);
    emit authStateChanged();
}

void JellyfinBackend::load_libraries() {
    const QString base = serverUrl();
    const QString uid = userId();
    if (base.isEmpty() || uid.isEmpty()) {
        handleAuthFailure("Jellyfin is not signed in.");
        return;
    }

    QUrl url(base + "/UserViews");
    QUrlQuery query;
    query.addQueryItem("userId", uid);
    query.addQueryItem("includeExternalContent", "false");
    query.addQueryItem("includeHidden", "false");
    url.setQuery(query);

    QNetworkReply *reply = jellyfinGet(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit errorOccurred(QString("Could not load Jellyfin libraries (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred("Jellyfin libraries response was invalid.");
            return;
        }

        QVariantList libraries;
        const QJsonArray items = doc.object()["Items"].toArray();
        for (const QJsonValue &value : items) {
            const QJsonObject item = value.toObject();
            const QVariantMap formatted = formatLibrary(item);
            if (!formatted["id"].toString().isEmpty())
                libraries.append(formatted);
        }
        emit librariesLoaded(libraries);
    });
}

void JellyfinBackend::load_items(const QString &libraryId) {
    const QString base = serverUrl();
    const QString uid = userId();
    if (base.isEmpty() || uid.isEmpty() || libraryId.isEmpty()) {
        emit errorOccurred("Jellyfin library selection is invalid.");
        return;
    }

    const int generation = ++m_itemsLoadGeneration;
    m_itemsLoadAccumulator.clear();
    if (m_itemCache.contains(libraryId)) {
        const QVariantList cached = m_itemCache.value(libraryId);
        emit itemsPageLoaded(cached, true, true);
        return;
    }

    load_items_page(libraryId, 0, generation);
}

void JellyfinBackend::load_items_page(const QString &libraryId, int startIndex, int generation) {
    if (generation != m_itemsLoadGeneration)
        return;

    const QString base = serverUrl();
    const QString uid = userId();
    if (base.isEmpty() || uid.isEmpty() || libraryId.isEmpty()) {
        emit errorOccurred("Jellyfin library selection is invalid.");
        return;
    }

    QUrl url(base + "/Items");
    QUrlQuery query;
    query.addQueryItem("userId", uid);
    query.addQueryItem("parentId", libraryId);
    query.addQueryItem("recursive", "true");
    query.addQueryItem("includeItemTypes", "Movie");
    query.addQueryItem("fields", "RunTimeTicks,ProductionYear,UserData");
    query.addQueryItem("enableImages", "false");
    query.addQueryItem("enableTotalRecordCount", "false");
    query.addQueryItem("startIndex", QString::number(startIndex));
    query.addQueryItem("limit", QString::number(kItemsPageSize));
    query.addQueryItem("sortBy", "SortName");
    query.addQueryItem("sortOrder", "Ascending");
    url.setQuery(query);

    QNetworkReply *reply = jellyfinGet(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply, libraryId, startIndex, generation]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (generation != m_itemsLoadGeneration)
            return;

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit errorOccurred(QString("Could not load Jellyfin items (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred("Jellyfin items response was invalid.");
            return;
        }

        QVariantList pageItems;
        const QJsonArray rawItems = doc.object()["Items"].toArray();
        for (const QJsonValue &value : rawItems) {
            const QJsonObject item = value.toObject();
            const QVariantMap formatted = formatItem(item);
            if (!formatted["id"].toString().isEmpty()) {
                pageItems.append(formatted);
                m_itemsLoadAccumulator.append(formatted);
            }
        }

        const bool finished = rawItems.size() < kItemsPageSize;
        emit itemsPageLoaded(pageItems, startIndex == 0, finished);

        if (finished) {
            m_itemCache.insert(libraryId, m_itemsLoadAccumulator);
            m_itemsLoadAccumulator.clear();
            return;
        }

        load_items_page(libraryId, startIndex + rawItems.size(), generation);
    });
}

void JellyfinBackend::load_item_detail(const QString &itemId) {
    const QString base = serverUrl();
    const QString uid = userId();
    if (base.isEmpty() || uid.isEmpty() || itemId.isEmpty()) {
        emit errorOccurred("Jellyfin item selection is invalid.");
        return;
    }

    QUrl url(base + "/Items/" + itemId);
    QUrlQuery query;
    query.addQueryItem("userId", uid);
    query.addQueryItem("fields", "Overview,RunTimeTicks,ProductionYear,UserData,MediaSources");
    url.setQuery(query);

    QNetworkReply *reply = jellyfinGet(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit errorOccurred(QString("Could not load Jellyfin item (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred("Jellyfin item response was invalid.");
            return;
        }

        emit itemLoaded(formatItem(doc.object()));
    });
}

void JellyfinBackend::build_stream_url(const QString &itemId, const QString &mediaSourceId) {
    const QString base = serverUrl();
    const QString token = accessToken();
    if (base.isEmpty() || token.isEmpty() || itemId.isEmpty()) {
        emit errorOccurred("Jellyfin stream request is missing authentication.");
        return;
    }

    QUrl url(base + "/Videos/" + itemId + "/stream");
    QUrlQuery query;
    query.addQueryItem("static", "true");
    query.addQueryItem("deviceId", deviceId());
    if (!mediaSourceId.isEmpty())
        query.addQueryItem("mediaSourceId", mediaSourceId);
    url.setQuery(query);

    QVariantList headers;
    headers.append(QString("X-Emby-Token:%1").arg(token));
    emit streamUrlReady(url.toString(), headers);
}

bool JellyfinBackend::saveAuthenticationResult(const QJsonObject &result, const QString &baseUrl) {
    const QJsonObject user = result["User"].toObject();
    const QString token = result["AccessToken"].toString();
    const QString id = user["Id"].toString();
    if (token.isEmpty() || id.isEmpty())
        return false;

    QJsonObject auth = loadAuth();
    ++m_itemsLoadGeneration;
    m_itemsLoadAccumulator.clear();
    m_itemCache.clear();
    auth["serverUrl"] = baseUrl;
    auth["accessToken"] = token;
    auth["userId"] = id;
    auth["username"] = user["Name"].toString();
    auth["serverId"] = result["ServerId"].toString();
    auth["serverName"] = QUrl(baseUrl).host();
    saveAuth(auth);
    return true;
}

void JellyfinBackend::pollQuickConnect() {
    if (m_quickConnectServerUrl.isEmpty() || m_quickConnectSecret.isEmpty()) {
        cancel_quick_connect();
        return;
    }

    m_quickConnectTimer->stop();

    QUrl url(m_quickConnectServerUrl + "/QuickConnect/Connect");
    QUrlQuery query;
    query.addQueryItem("secret", m_quickConnectSecret);
    url.setQuery(query);

    QNetworkReply *reply = m_nam->get(jellyfinRequest(url, QString(), false));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            cancel_quick_connect();
            emit errorOccurred(QString("Quick Connect polling failed (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            cancel_quick_connect();
            emit errorOccurred("Quick Connect polling returned an invalid response.");
            return;
        }

        if (doc.object()["Authenticated"].toBool(false)) {
            authenticateWithQuickConnectSecret();
        } else if (!m_quickConnectSecret.isEmpty()) {
            m_quickConnectTimer->start();
        }
    });
}

void JellyfinBackend::authenticateWithQuickConnectSecret() {
    if (m_quickConnectServerUrl.isEmpty() || m_quickConnectSecret.isEmpty()) {
        emit errorOccurred("Quick Connect authentication is missing a secret.");
        return;
    }

    QJsonObject body;
    body["Secret"] = m_quickConnectSecret;

    const QString base = m_quickConnectServerUrl;
    QNetworkReply *reply = jellyfinPostJson(QUrl(base + "/Users/AuthenticateWithQuickConnect"),
                                            QJsonDocument(body).toJson(QJsonDocument::Compact),
                                            QString(),
                                            false);
    connect(reply, &QNetworkReply::finished, this, [this, reply, base]() {
        const QByteArray data = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        reply->deleteLater();

        if (error != QNetworkReply::NoError || status < 200 || status >= 300) {
            cancel_quick_connect();
            emit errorOccurred(QString("Quick Connect sign-in failed (%1).").arg(status > 0 ? status : int(error)));
            return;
        }

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            cancel_quick_connect();
            emit errorOccurred("Quick Connect sign-in returned an invalid response.");
            return;
        }

        if (!saveAuthenticationResult(doc.object(), base)) {
            cancel_quick_connect();
            emit errorOccurred("Quick Connect sign-in did not return a usable access token.");
            return;
        }

        cancel_quick_connect();
        emit authSuccess();
        emit authStateChanged();
    });
}

void JellyfinBackend::getVideoQualities() {
    QVariantList opts;
    opts.append(QVariantMap{{"id", "direct"}, {"label", "Direct Play"}});
    emit dynamicOptionsReady("video_quality", opts);
}

void JellyfinBackend::get_resume_playback_options() {
    QVariantList opts;
    opts.append(QVariantMap{{"id", "ask"}, {"label", "Ask"}});
    opts.append(QVariantMap{{"id", "yes"}, {"label", "Always Resume"}});
    opts.append(QVariantMap{{"id", "no"}, {"label", "Start Over"}});
    emit dynamicOptionsReady("resume_playback", opts);
}

QVariantMap JellyfinBackend::formatLibrary(const QJsonObject &item) const {
    QVariantMap out;
    out["id"] = item["Id"].toString();
    out["title"] = item["Name"].toString();
    out["collectionType"] = item["CollectionType"].toString();
    return out;
}

QString JellyfinBackend::itemTitle(const QJsonObject &item) {
    const QString type = item["Type"].toString();
    if (type == "Episode") {
        const QString series = item["SeriesName"].toString();
        const QString name = item["Name"].toString();
        if (!series.isEmpty() && !name.isEmpty())
            return QString("%1 - %2").arg(series, name);
    }
    return item["Name"].toString();
}

static QString jellyfinStreamLabel(const QJsonObject &stream, const QString &fallbackPrefix, int trackNumber) {
    QString label = stream["DisplayTitle"].toString().trimmed();
    if (label.isEmpty()) {
        const QString language = stream["Language"].toString().toUpper();
        const QString title = stream["Title"].toString().trimmed();
        const QString codec = stream["Codec"].toString().toUpper();
        const int channels = stream["Channels"].toInt();

        if (!language.isEmpty() && !title.isEmpty())
            label = language + " - " + title;
        else if (!title.isEmpty())
            label = title;
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
    }
    return label.toUpper();
}

static QString jellyfinSubtitleUrl(const QString &base, const QJsonObject &stream) {
    QString deliveryUrl = stream["DeliveryUrl"].toString();
    if (deliveryUrl.isEmpty())
        return {};

    QUrl url(deliveryUrl);
    if (url.isRelative()) {
        if (!deliveryUrl.startsWith('/'))
            deliveryUrl.prepend('/');
        url = QUrl(base + deliveryUrl);
    }

    QUrlQuery query(url);
    if (query.hasQueryItem("api_key")) {
        query.removeAllQueryItems("api_key");
        url.setQuery(query);
    }
    return url.toString();
}

QVariantMap JellyfinBackend::formatItem(const QJsonObject &item) const {
    QVariantMap out;
    out["id"] = item["Id"].toString();
    out["title"] = itemTitle(item);
    out["name"] = item["Name"].toString();
    out["type"] = item["Type"].toString().toLower();
    out["summary"] = item["Overview"].toString();
    out["year"] = item["ProductionYear"].toInt();
    out["duration"] = ticksToMs(item["RunTimeTicks"].toVariant().toLongLong());

    const QJsonObject userData = item["UserData"].toObject();
    out["viewOffset"] = ticksToMs(userData["PlaybackPositionTicks"].toVariant().toLongLong());
    out["played"] = userData["Played"].toBool(false);

    const QJsonArray mediaSources = item["MediaSources"].toArray();
    QJsonArray streams = item["MediaStreams"].toArray();
    if (!mediaSources.isEmpty()) {
        const QJsonObject mediaSource = mediaSources.first().toObject();
        out["mediaSourceId"] = mediaSource["Id"].toString();
        const QJsonArray mediaSourceStreams = mediaSource["MediaStreams"].toArray();
        if (!mediaSourceStreams.isEmpty())
            streams = mediaSourceStreams;
    }

    QVariantList audioStreams;
    QVariantList subtitleStreams;
    int audioTrack = 0;
    int embeddedSubtitleTrack = 0;
    int subtitleTrack = 0;
    QString base;

    for (const QJsonValue &value : streams) {
        const QJsonObject stream = value.toObject();
        const QString type = stream["Type"].toString();
        if (type.compare("Audio", Qt::CaseInsensitive) == 0) {
            ++audioTrack;
            audioStreams.append(QVariantMap{
                {"id", QString::number(stream["Index"].toInt(audioTrack))},
                {"streamIndex", stream["Index"].toInt(-1)},
                {"mpvTrack", audioTrack},
                {"displayTitle", jellyfinStreamLabel(stream, "AUDIO", audioTrack)}
            });
        } else if (type.compare("Subtitle", Qt::CaseInsensitive) == 0) {
            ++subtitleTrack;
            const bool isExternal = stream["IsExternal"].toBool(false);
            QString subUrl;
            int mpvTrack = 0;
            if (isExternal) {
                if (base.isEmpty())
                    base = serverUrl();
                subUrl = jellyfinSubtitleUrl(base, stream);
                if (subUrl.isEmpty())
                    continue;
            } else {
                ++embeddedSubtitleTrack;
                mpvTrack = embeddedSubtitleTrack;
            }

            subtitleStreams.append(QVariantMap{
                {"id", QString::number(stream["Index"].toInt(subtitleTrack))},
                {"streamIndex", stream["Index"].toInt(-1)},
                {"mpvTrack", mpvTrack},
                {"displayTitle", jellyfinStreamLabel(stream, "SUBTITLE", subtitleTrack)},
                {"isExternal", isExternal},
                {"subFile", subUrl}
            });
        }
    }

    out["audioStreams"] = audioStreams;
    out["subtitleStreams"] = subtitleStreams;

    return out;
}

int JellyfinBackend::ticksToMs(qint64 ticks) {
    if (ticks <= 0)
        return 0;
    return int(ticks / 10000);
}
