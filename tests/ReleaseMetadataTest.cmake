if(NOT DEFINED SOURCE_ROOT OR NOT IS_ABSOLUTE "${SOURCE_ROOT}")
    message(FATAL_ERROR "SOURCE_ROOT must be an absolute path")
endif()
if(NOT DEFINED RELEASE_VERSION OR RELEASE_VERSION STREQUAL "")
    message(FATAL_ERROR "RELEASE_VERSION is required")
endif()

file(READ "${SOURCE_ROOT}/README.md" readme)
file(READ "${SOURCE_ROOT}/CHANGELOG.md" changelog)
file(READ "${SOURCE_ROOT}/INSTALL.md" install_guide)

set(expected_download_url
    "https://github.com/aindaco1/240-mp-jellyfin/releases/download/v${RELEASE_VERSION}/240-mp-jellyfin-v${RELEASE_VERSION}-macOS-arm64.dmg")
string(FIND "${readme}" "${expected_download_url}" download_url_index)
if(download_url_index EQUAL -1)
    message(FATAL_ERROR "README direct DMG URL does not match ${RELEASE_VERSION}")
endif()

string(FIND "${changelog}" "## [${RELEASE_VERSION}] - " changelog_version_index)
if(changelog_version_index EQUAL -1)
    message(FATAL_ERROR "CHANGELOG has no dated ${RELEASE_VERSION} section")
endif()

string(FIND "${install_guide}" "onto the Applications shortcut" install_instruction_index)
if(install_instruction_index EQUAL -1)
    message(FATAL_ERROR "INSTALL does not describe the DMG Applications shortcut")
endif()
