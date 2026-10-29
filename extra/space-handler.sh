#!/usr/bin/env bash
# Forward a byond:// URL from the host browser to BYOND inside the wine prefix.
set -euo pipefail

self="$(readlink -f "$0")"

# --register: make this script the host's handler for byond links.
if [ "${1:-}" = "--register" ]; then
    command -v xdg-mime >/dev/null || {
        echo "Error: xdg-mime not found; cannot register the handler." >&2
        exit 0
    }
    apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$apps"
    cat > "$apps/byond-url-handler.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=BYOND URL Handler
Exec="$self" %u
NoDisplay=true
Terminal=false
MimeType=x-scheme-handler/byond;
EOF
    command -v update-desktop-database >/dev/null && update-desktop-database "$apps" || true
    xdg-mime default byond-url-handler.desktop x-scheme-handler/byond
    echo "Registered $self as the byond url handler."
    exit 0
fi

url="${1:-}"
[ -n "$url" ] || { echo "usage: $0 <byond-url> | --register" >&2; exit 1; }

export WINEPREFIX="${WINEPREFIX:-$(dirname "$self")}"
export WINEDEBUG="${WINEDEBUG:--all}"

in_prefix() {
    tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -qxF "WINEPREFIX=$WINEPREFIX"
}

# Sets server_exe if the pager is running in this prefix.
find_pager() {
    server_exe=""
    local pid
    for byond_pid in $(pgrep -if 'byond\.exe'); do
        in_prefix "$byond_pid" || continue
        for pid in $(pgrep -x wineserver); do
            if in_prefix "$pid"; then server_exe="$(readlink -f "/proc/$pid/exe")"; return 0; fi
        done
    done
    return 1
}

# Lutris game ID: $LUTRIS_GAME_ID, then a "lutris-id" file next to this script
# (an install script can write it), then a lookup by prefix directory.
lutris_id() {
    local dir; dir="$(dirname "$(readlink -f "$0")")"
    if [ -n "${LUTRIS_GAME_ID:-}" ]; then echo "$LUTRIS_GAME_ID"
    elif [ -s "$dir/lutris-id" ]; then head -n1 "$dir/lutris-id"
    elif command -v sqlite3 >/dev/null; then
        sqlite3 "$HOME/.local/share/lutris/pga.db" \
            "select id from games where directory='${WINEPREFIX//\'/\'\'}' limit 1" 2>/dev/null
    fi
}

if ! find_pager; then
    id="$(lutris_id)"
    [ -n "$id" ] || { echo "BYOND is not running and no Lutris game ID found." >&2; exit 1; }
    LUTRIS_SKIP_INIT=1 setsid lutris "lutris:rungameid/$id" >/dev/null 2>&1 &
    for _ in $(seq 24); do
        sleep 5
        find_pager && break
    done
    [ -n "$server_exe" ] || { echo "Timed out waiting for BYOND to start." >&2; exit 1; }
    sleep 10
fi

# Use the wine build matching the running wineserver.
WINE="${WINE:-$(dirname "$server_exe")/wine}"

# 64-bit prefixes use "Program Files (x86)"; win32 prefixes use "Program Files".
location="Program Files (x86)"
[ -d "$WINEPREFIX/drive_c/$location/BYOND" ] || location="Program Files"

exec "$WINE" "C:\\$location\\BYOND\\bin\\byond.exe" -url "$url"
