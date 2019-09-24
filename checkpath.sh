#!/bin/sh

set -ex

temp() {
    apk --update --quiet --no-progress add git jq

    IGNORED_PATHS="$(echo "$IGNORED_PATHS" | jq -r '":!" + (. // [])[]')"
    test -z "$IGNORED_PATHS" && exit 0

    HEAD=$(jq -r '.[] | select(.name=="head_sha") .value' .git/resource/metadata.json)
    BASE=$(jq -r '.[] | select(.name=="base_sha") .value' .git/resource/metadata.json)

    git diff --name-only "${BASE}~1..${HEAD}" -- ${IGNORED_PATHS} >../changed-files/files.txt
}

_checkpath_is_pkg_installed() {
    command -v "$1" >/dev/null
}

_checkpath_install_pkg() {
    pkgman="$1"
    pkg="$2"
    case $pkgman in
        apk)
            apk --update --quiet --no-progress add "$pkg"
            ;;
        apt-get)
            apt-get install --quiet --yes "$pkg"
            ;;
        *)
            return 1
            ;;
    esac
}

_checkpath_detect_pkgman() {
    for pkgman in "apk" "apt-get"; do
        if _checkpath_is_pkg_installed "$pkgman"; then
            echo "$pkgman"
            break
        fi
    done
}

_checkpath_prepare() {
    pkgman=$(_checkpath_detect_pkgman)
    test -z "$pkgman" && return 1
    test "$pkgman" = "apt-get" && apt-get update -q
    _checkpath_is_pkg_installed git || _checkpath_install_pkg "$pkgman" git
    _checkpath_is_pkg_installed jq || _checkpath_install_pkg "$pkgman" jq
}

_checkpath_prepare
