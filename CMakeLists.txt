cmake_minimum_required(VERSION 3.21)
project(240mp VERSION 1.0 LANGUAGES CXX)

if(NOT APPLE)
    message(FATAL_ERROR "This fork is macOS-only. Configure and build it on macOS.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(APP_DISPLAY_NAME "240-mp-jellyfin")

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Network Svg)
find_package(OpenSSL REQUIRED)
find_program(MPV_EXECUTABLE NAMES mpv)
find_program(FFPROBE_EXECUTABLE NAMES ffprobe)

if(MPV_EXECUTABLE)
    get_filename_component(MPV_EXECUTABLE_REAL "${MPV_EXECUTABLE}" REALPATH)
    message(STATUS "mpv found and will be bundled for packaged macOS apps: ${MPV_EXECUTABLE_REAL}")
else()
    message(WARNING "mpv was not found. Packaged apps will still build, but playback will require mpv on PATH.")
endif()

if(FFPROBE_EXECUTABLE)
    get_filename_component(FFPROBE_EXECUTABLE_REAL "${FFPROBE_EXECUTABLE}" REALPATH)
    message(STATUS "ffprobe found and will be bundled for packaged macOS apps: ${FFPROBE_EXECUTABLE_REAL}")
else()
    message(WARNING "ffprobe was not found. Packaged apps will still run, but local track probing will require ffprobe on PATH.")
endif()

enable_language(OBJCXX)

add_executable(240mp
    src/main.cpp
    src/AppCore.cpp
    src/modules/local_files/LocalFilesBackend.cpp
    src/modules/plex/PlexBackend.cpp
    src/modules/jellyfin/JellyfinBackend.cpp
    src/modules/ambient_mode/AmbientModeBackend.cpp
    src/player/MpvController.cpp
    src/macos_utils.mm
)

target_link_libraries(240mp PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::Network
    Qt6::Svg
    OpenSSL::Crypto
    "-framework AppKit"
)

target_include_directories(240mp PRIVATE
    src
)

# ── macOS bundle metadata ──────────────────────────────────────────────────────
set_target_properties(240mp PROPERTIES
    OUTPUT_NAME "${APP_DISPLAY_NAME}"
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "${APP_DISPLAY_NAME}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.240mp.jellyfin"
    MACOSX_BUNDLE_ICON_FILE "assets/images/240-mp"
    INSTALL_RPATH_USE_LINK_PATH TRUE
)

# ── Dev bundle symlink (macOS only, non-CI) ───────────────────────────────────
# Makes double-clicking the app bundle work during development by symlinking
# Contents/Resources → repo root so resolveAppRoot() finds the QML files.
# Skipped in CI (ENV{CI} is set by GitHub Actions) because cmake --install
# populates Resources with real files — a symlink in the build tree would be
# packaged into the DMG pointing to a CI path that doesn't exist on end-user Macs.
if(APPLE AND NOT DEFINED ENV{CI})
    add_custom_command(TARGET 240mp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E remove -f
            "$<TARGET_BUNDLE_CONTENT_DIR:240mp>/Resources"
        COMMAND ${CMAKE_COMMAND} -E create_symlink
            "${CMAKE_SOURCE_DIR}"
            "$<TARGET_BUNDLE_CONTENT_DIR:240mp>/Resources"
        COMMENT "Symlinking repo root as bundle Resources (dev build)"
    )
endif()

# ── Install rules ──────────────────────────────────────────────────────────────
install(TARGETS 240mp BUNDLE DESTINATION . COMPONENT Runtime)

# Dev builds symlink Contents/Resources to the repo root. If a local
# cmake --install copies that symlink, subsequent install rules write back
# into the source tree. Replace it with a real Resources directory in the
# install image before copying app resources and helper tools.
install(CODE "
    set(installed_resources \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${APP_DISPLAY_NAME}.app/Contents/Resources\")
    execute_process(COMMAND /bin/rm -rf \"\${installed_resources}\")
    file(MAKE_DIRECTORY \"\${installed_resources}\")
")

# Use a hardcoded relative path — $<TARGET_BUNDLE_CONTENT_DIR> resolves to
# the build tree, not the install prefix, inside install() rules.
install(FILES "${CMAKE_SOURCE_DIR}/Main.qml"
    DESTINATION "${APP_DISPLAY_NAME}.app/Contents/Resources"
    COMPONENT Runtime)

install(DIRECTORY
    "${CMAKE_SOURCE_DIR}/views"
    "${CMAKE_SOURCE_DIR}/modules"
    "${CMAKE_SOURCE_DIR}/assets"
    DESTINATION "${APP_DISPLAY_NAME}.app/Contents/Resources"
    COMPONENT Runtime)

install(FILES
    "${CMAKE_SOURCE_DIR}/scripts/ambient-osc.lua"
    "${CMAKE_SOURCE_DIR}/scripts/mpv-osc.lua"
    DESTINATION "${APP_DISPLAY_NAME}.app/Contents/Resources/scripts"
    COMPONENT Runtime)

if(MPV_EXECUTABLE)
    install(CODE "
        execute_process(
            COMMAND /bin/zsh
                \"${CMAKE_SOURCE_DIR}/scripts/macos_bundle_tool_deps.zsh\"
                \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${APP_DISPLAY_NAME}.app\"
                \"${MPV_EXECUTABLE_REAL}\"
                \"Contents/Resources/bin\"
            RESULT_VARIABLE bundle_mpv_result
        )
        if(NOT bundle_mpv_result EQUAL 0)
            message(FATAL_ERROR \"Failed to bundle mpv into ${APP_DISPLAY_NAME}.app\")
        endif()
    ")
endif()

if(FFPROBE_EXECUTABLE)
    install(CODE "
        execute_process(
            COMMAND /bin/zsh
                \"${CMAKE_SOURCE_DIR}/scripts/macos_bundle_tool_deps.zsh\"
                \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${APP_DISPLAY_NAME}.app\"
                \"${FFPROBE_EXECUTABLE_REAL}\"
                \"Contents/Resources/bin\"
            RESULT_VARIABLE bundle_ffprobe_result
        )
        if(NOT bundle_ffprobe_result EQUAL 0)
            message(FATAL_ERROR \"Failed to bundle ffprobe into ${APP_DISPLAY_NAME}.app\")
        endif()
    ")
endif()

# macdeployqt is NOT run here — it requires Qt frameworks to be present and
# is environment-specific. Run it manually in CI after cmake --install.

# ── CPack ──────────────────────────────────────────────────────────────────────
set(CPACK_PACKAGE_NAME "${APP_DISPLAY_NAME}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "240-mp-jellyfin Media Player")
set(CPACK_PACKAGE_VENDOR "240-mp-jellyfin")

set(CPACK_GENERATOR "DragNDrop")
set(CPACK_DMG_VOLUME_NAME "${APP_DISPLAY_NAME}")
set(CPACK_DMG_FORMAT "UDZO")

include(CPack)
