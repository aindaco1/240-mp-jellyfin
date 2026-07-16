#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QDir>
#include <QStandardPaths>
#include <QCursor>
#include <QDebug>
#include <QWindow>
#include <QQuickWindow>
#include <QScreen>
#include <QVariant>
#include <locale.h>

#include "AppCore.h"
#include "modules/local_files/LocalFilesBackend.h"
#include "modules/plex/PlexBackend.h"
#include "modules/jellyfin/JellyfinBackend.h"
#include "modules/karaoke/KaraokeBackend.h"
#include "modules/ambient_mode/AmbientModeBackend.h"
#include "modules/tumblr_screensaver/TumblrScreensaverBackend.h"
#include "player/MpvController.h"
#include "input/IdleTracker.h"
#include "input/InputManager.h"
#include "update/UpdateManager.h"
#ifdef Q_OS_MAC
#include "macos_utils.h"
#endif

static QString resolveAppRoot() {
    QString envRoot = qEnvironmentVariable("APP_ROOT");
    if (!envRoot.isEmpty())
        return QDir(envRoot).canonicalPath();

    QString appDir = QCoreApplication::applicationDirPath();

    if (QCoreApplication::applicationFilePath().contains(".app/Contents/MacOS/"))
        return QDir(appDir + "/../Resources").canonicalPath();

    QDir fhsData(appDir + "/../share/240-mp-jellyfin");
    if (fhsData.exists())
        return fhsData.canonicalPath();

    return QDir(appDir + "/..").canonicalPath();
}

static QString resolveDataRoot() {
    QString envRoot = qEnvironmentVariable("DATA_ROOT");
    if (!envRoot.isEmpty()) {
        QDir().mkpath(envRoot);
        return QDir(envRoot).canonicalPath();
    }

    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
    return path;
}

static QScreen *resolveExternalMediaScreen() {
    const QList<QScreen *> screens = QGuiApplication::screens();
    QScreen *primary = QGuiApplication::primaryScreen();
    for (QScreen *screen : screens) {
        if (screen && screen != primary)
            return screen;
    }
    return nullptr;
}

static bool preventSleepEnabledFromSettings(AppCore &appCore) {
    const QString value = appCore.get_setting("", "prevent_sleep").toString().trimmed();
    return value.isEmpty() || value.compare(QStringLiteral("ON"), Qt::CaseInsensitive) == 0;
}

static int lowBatteryThresholdFromSettings(AppCore &appCore) {
    QString value = appCore.get_setting("", "battery_sleep_threshold").toString().trimmed();
    if (value.isEmpty())
        return 10;
    if (value.compare(QStringLiteral("OFF"), Qt::CaseInsensitive) == 0)
        return -1;
    value.remove('%');
    bool ok = false;
    const int threshold = value.toInt(&ok);
    return ok ? qBound(1, threshold, 100) : 10;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("240-mp-jellyfin");
#ifdef APP_VERSION
    app.setApplicationVersion(QStringLiteral(APP_VERSION));
#else
    app.setApplicationVersion(QStringLiteral("dev"));
#endif

    // Hide cursor — this app is keyboard-only so the cursor serves no purpose.
    // On Linux, only hide on headless EGLFS (not desktop X11/Wayland sessions).
#ifdef Q_OS_LINUX
    if (qgetenv("DISPLAY").isEmpty() && qgetenv("WAYLAND_DISPLAY").isEmpty())
        QGuiApplication::setOverrideCursor(Qt::BlankCursor);
#endif
#ifdef Q_OS_MAC
    QGuiApplication::setOverrideCursor(Qt::BlankCursor);
    hideMacOSMenuBar();
    int macW = macMainScreenWidth();
    int macH = macMainScreenHeight();
    qDebug("[main] macOS NSScreen main frame: %dx%d", macW, macH);
#endif

    setlocale(LC_NUMERIC, "C");

    const QString appRoot  = resolveAppRoot();
    const QString dataRoot = resolveDataRoot();
    qDebug("[main] appRoot  = %s", qPrintable(appRoot));
    qDebug("[main] dataRoot = %s", qPrintable(dataRoot));

    QQmlApplicationEngine engine;

    AppCore             appCore(appRoot, dataRoot);
    LocalFilesBackend   localFiles(appRoot, dataRoot);
    PlexBackend         plexBackend(appRoot, dataRoot);
    JellyfinBackend     jellyfinBackend(appRoot, dataRoot);
    KaraokeBackend      karaokeBackend(appRoot, dataRoot);
    AmbientModeBackend  ambientMode(appRoot, dataRoot);
    TumblrScreensaverBackend tumblrScreensaver;
    MpvController       mpvController(appRoot, &appCore);
    IdleTracker         idleTracker;
    InputManager        inputManager;
    UpdateManager       updateManager(dataRoot);
    QObject::connect(&inputManager, &InputManager::mpvKeyRequested,
                     &mpvController, &MpvController::sendKey);

#ifdef Q_OS_MAC
    auto applySleepPreventionSettings = [&appCore]() {
        configureMacSleepPrevention(preventSleepEnabledFromSettings(appCore),
                                    lowBatteryThresholdFromSettings(appCore));
    };
    applySleepPreventionSettings();
    QObject::connect(&appCore, &AppCore::appSettingChanged, &app,
                     [&applySleepPreventionSettings](const QString &key, const QString &) {
        if (key == QStringLiteral("prevent_sleep") ||
            key == QStringLiteral("battery_sleep_threshold")) {
            applySleepPreventionSettings();
        }
    });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, [] {
        stopMacSleepPrevention();
    });
#endif

    // Each module backend is wired in one call: stored for action routing, exposed to QML
    // under its context-property name, and its optional signals/slots connected by
    // introspection. The module ID lives in exactly one place per module.
    QQmlContext *ctx = engine.rootContext();
    appCore.registerModule("com.240mp.local_files",  "localFilesBackend",  &localFiles,  ctx);
    appCore.registerModule("com.240mp.plex",         "plexBackend",        &plexBackend, ctx);
    appCore.registerModule("com.240mp.jellyfin",     "jellyfinBackend",    &jellyfinBackend, ctx);
    appCore.registerModule("com.240mp.karaoke",      "karaokeBackend",     &karaokeBackend, ctx);
    appCore.registerModule("com.240mp.ambient_mode", "ambientModeBackend", &ambientMode, ctx);
    appCore.registerModule("com.240mp.tumblr_screensaver", "tumblrScreensaverBackend", &tumblrScreensaver, ctx);

    ctx->setContextProperty("appCore",       &appCore);
    ctx->setContextProperty("mpvController", &mpvController);
    ctx->setContextProperty("idleTracker",   &idleTracker);
    ctx->setContextProperty("inputManager",  &inputManager);
    ctx->setContextProperty("updateManager", &updateManager);
    QScreen *externalMediaScreen = resolveExternalMediaScreen();
    QRect externalMediaGeometry = externalMediaScreen ? externalMediaScreen->geometry() : QRect(0, 0, macW, macH);
    ctx->setContextProperty("hasExternalMediaScreen", externalMediaScreen != nullptr);
    ctx->setContextProperty("externalMediaScreenX", externalMediaGeometry.x());
    ctx->setContextProperty("externalMediaScreenY", externalMediaGeometry.y());
    ctx->setContextProperty("externalMediaScreenWidth", externalMediaGeometry.width());
    ctx->setContextProperty("externalMediaScreenHeight", externalMediaGeometry.height());
#ifdef Q_OS_MAC
    engine.rootContext()->setContextProperty("macScreenX",      QVariant::fromValue(0));
    engine.rootContext()->setContextProperty("macScreenY",      QVariant::fromValue(0));
    engine.rootContext()->setContextProperty("macScreenWidth",  macW);
    engine.rootContext()->setContextProperty("macScreenHeight", macH);
#endif

    engine.addImportPath(appRoot + "/views");

    engine.load(QUrl::fromLocalFile(appRoot + "/Main.qml"));
    if (engine.rootObjects().isEmpty()) {
        qCritical("[main] QML engine failed to load Main.qml");
        return 1;
    }
    if (QQuickWindow *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
        inputManager.setTargetWindow(window);

#ifdef Q_OS_MAC
    if (QWindow *win = qobject_cast<QWindow *>(engine.rootObjects().first())) {
        win->winId(); // ensure native NSWindow is created
        forceWindowFullScreen(reinterpret_cast<void *>(win->winId()));
    }
#endif

    return app.exec();
}
