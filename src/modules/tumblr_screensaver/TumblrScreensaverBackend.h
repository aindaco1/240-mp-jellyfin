#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QSet>
#include <QUrl>
#include <QVariantList>

class QNetworkReply;
class QJsonObject;
class TumblrScreensaverBackendTest;

class TumblrScreensaverBackend : public QObject {
    Q_OBJECT

public:
    explicit TumblrScreensaverBackend(QObject *parent = nullptr);

    Q_INVOKABLE void loadImages(const QString &tumblrUrl);
    Q_INVOKABLE QString normalizeBlogUrl(const QString &tumblrUrl) const;

signals:
    void loadStarted(const QString &sourceUrl);
    void loadProgress(int imageCount, int postsSeen, int totalPosts);
    void imagesLoaded(const QVariantList &images, const QString &blogTitle, int totalPosts);
    void errorOccurred(const QString &message);

private:
    friend class TumblrScreensaverBackendTest;
    QUrl normalizedBlogUrl(const QString &tumblrUrl) const;
    QUrl apiUrlForPage(const QUrl &blogUrl, int start) const;
    void fetchPage(const QUrl &blogUrl, int start, int generation);
    void handlePage(QNetworkReply *reply, const QUrl &blogUrl, int start, int generation);
    QVariantList imagesFromPost(const QJsonObject &post) const;
    void finishLoad();
    void failLoad(const QString &message);

    QNetworkAccessManager *m_nam;
    int m_generation = 0;
    int m_postsSeen = 0;
    int m_totalPosts = -1;
    QString m_blogTitle;
    QVariantList m_images;
    QSet<QString> m_seenUrls;
};
