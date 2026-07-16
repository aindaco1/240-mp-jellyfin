set(YT_DLP_VERSION "2026.07.04" CACHE STRING "Pinned yt-dlp release")
set(YT_DLP_SHA256 "498bd0dae17855c599d371d68ec5bafc439a9d8640e838be25c765a9792f261b"
    CACHE STRING "SHA-256 for the pinned yt-dlp_macos executable")
set(DENO_VERSION "2.9.3" CACHE STRING "Pinned Deno release")
set(DENO_SHA256 "1b2972f7ceb6df28d9600eab18d423bebb9aa18db02f01d7eb37a5b501482203"
    CACHE STRING "SHA-256 for the pinned Deno Apple Silicon archive")

set(YT_DLP_EXECUTABLE_OVERRIDE "" CACHE FILEPATH
    "Use an existing yt-dlp executable instead of downloading the pinned helper")
set(DENO_EXECUTABLE_OVERRIDE "" CACHE FILEPATH
    "Use an existing Deno executable instead of downloading the pinned helper")

set(_helper_cache "${CMAKE_BINARY_DIR}/bundled-helpers")
file(MAKE_DIRECTORY "${_helper_cache}")

function(download_verified url destination expected_sha256)
    if(EXISTS "${destination}")
        file(SHA256 "${destination}" actual_sha256)
        if(NOT actual_sha256 STREQUAL expected_sha256)
            message(STATUS "Removing helper with stale checksum: ${destination}")
            file(REMOVE "${destination}")
        endif()
    endif()

    if(NOT EXISTS "${destination}")
        message(STATUS "Downloading pinned helper asset: ${url}")
        file(DOWNLOAD "${url}" "${destination}"
            EXPECTED_HASH "SHA256=${expected_sha256}"
            TLS_VERIFY ON
            SHOW_PROGRESS
            STATUS download_status)
        list(GET download_status 0 download_code)
        list(GET download_status 1 download_message)
        if(NOT download_code EQUAL 0)
            file(REMOVE "${destination}")
            message(FATAL_ERROR "Could not download ${url}: ${download_message}")
        endif()
    endif()
endfunction()

if(YT_DLP_EXECUTABLE_OVERRIDE)
    if(NOT EXISTS "${YT_DLP_EXECUTABLE_OVERRIDE}")
        message(FATAL_ERROR
            "YT_DLP_EXECUTABLE_OVERRIDE does not exist: ${YT_DLP_EXECUTABLE_OVERRIDE}")
    endif()
    set(YT_DLP_EXECUTABLE "${YT_DLP_EXECUTABLE_OVERRIDE}")
else()
    set(_yt_dlp_path "${_helper_cache}/yt-dlp-${YT_DLP_VERSION}")
    download_verified(
        "https://github.com/yt-dlp/yt-dlp/releases/download/${YT_DLP_VERSION}/yt-dlp_macos"
        "${_yt_dlp_path}"
        "${YT_DLP_SHA256}")
    file(CHMOD "${_yt_dlp_path}" PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE)
    set(YT_DLP_EXECUTABLE "${_yt_dlp_path}")
endif()

if(DENO_EXECUTABLE_OVERRIDE)
    if(NOT EXISTS "${DENO_EXECUTABLE_OVERRIDE}")
        message(FATAL_ERROR
            "DENO_EXECUTABLE_OVERRIDE does not exist: ${DENO_EXECUTABLE_OVERRIDE}")
    endif()
    set(DENO_EXECUTABLE "${DENO_EXECUTABLE_OVERRIDE}")
else()
    set(_deno_archive "${_helper_cache}/deno-${DENO_VERSION}-aarch64-apple-darwin.zip")
    set(_deno_dir "${_helper_cache}/deno-${DENO_VERSION}-aarch64-apple-darwin")
    set(_deno_path "${_deno_dir}/deno")
    download_verified(
        "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-aarch64-apple-darwin.zip"
        "${_deno_archive}"
        "${DENO_SHA256}")
    if(NOT EXISTS "${_deno_path}")
        file(REMOVE_RECURSE "${_deno_dir}")
        file(MAKE_DIRECTORY "${_deno_dir}")
        file(ARCHIVE_EXTRACT INPUT "${_deno_archive}" DESTINATION "${_deno_dir}")
    endif()
    if(NOT EXISTS "${_deno_path}")
        message(FATAL_ERROR "Pinned Deno archive did not contain a deno executable")
    endif()
    file(CHMOD "${_deno_path}" PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE)
    set(DENO_EXECUTABLE "${_deno_path}")
endif()

set(_yt_dlp_licenses "${_helper_cache}/yt-dlp-THIRD_PARTY_LICENSES.txt")
download_verified(
    "https://raw.githubusercontent.com/yt-dlp/yt-dlp/${YT_DLP_VERSION}/THIRD_PARTY_LICENSES.txt"
    "${_yt_dlp_licenses}"
    "b085c65586a953cdb4b13c6390d63ec984d66912e4b6a19e66ba3582f2ed104b")

set(_yt_dlp_license "${_helper_cache}/yt-dlp-LICENSE")
download_verified(
    "https://raw.githubusercontent.com/yt-dlp/yt-dlp/${YT_DLP_VERSION}/LICENSE"
    "${_yt_dlp_license}"
    "7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c")

set(_deno_license "${_helper_cache}/deno-LICENSE.md")
download_verified(
    "https://raw.githubusercontent.com/denoland/deno/v${DENO_VERSION}/LICENSE.md"
    "${_deno_license}"
    "f62497fffecc0852960c8d3e6934b9db86d16396e9b604072e923892cae3a588")

set(BUNDLED_YT_DLP_LICENSES "${_yt_dlp_license}" "${_yt_dlp_licenses}")
set(BUNDLED_DENO_LICENSE "${_deno_license}")
