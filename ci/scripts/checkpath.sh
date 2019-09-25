#!/bin/sh

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
    test "$pkgman" = "apt-get" && apt-get update --quiet
    _checkpath_is_pkg_installed git || _checkpath_install_pkg "$pkgman" git
    _checkpath_is_pkg_installed jq || _checkpath_install_pkg "$pkgman" jq
}

_checkpath_maybe_teliaoss_pr() {
    metadata_file=".git/resource/metadata.json"
    test ! -f "$metadata_file" && return
    HEAD=$(jq -r '.[] | select(.name=="head_sha") .value' "$metadata_file")
    BASE=$(jq -r '.[] | select(.name=="base_sha") .value' "$metadata_file")
    git diff --name-only "${BASE}..${HEAD}" | jq --raw-input --slurp 'split("\n") | map(select(. != ""))'
}

_checkpath_maybe_last_commit() {
    git diff --name-only "HEAD~1..HEAD" | jq --raw-input --slurp 'split("\n") | map(select(. != ""))'
}

_checkpath_is_required() {
    changed_paths_json=$1
    wanted_paths_json=$2

    for wanted_path in $(echo "$wanted_paths_json" | jq -r '.[]'); do
        if echo "$changed_paths_json" | jq -r '.[]' | grep "^$wanted_path"; then
            return
        fi
    done

    echo "CHECKPATHS doesn't have any changed path, skipping..."
    exit 0
}

checkpaths() {
    test -z "$CHECKPATHS" && exit 0
    _checkpath_prepare

    diff_paths=$(_checkpath_maybe_teliaoss_pr)
    if [ -n "$diff_paths" ]; then
        _checkpath_is_required "$diff_paths" "$CHECKPATHS"
        return
    fi

    diff_paths=$(_checkpath_maybe_last_commit)
    if [ -n "$diff_paths" ]; then
        _checkpath_is_required "$diff_paths" "$CHECKPATHS"
        return
    fi
}

checkpaths
