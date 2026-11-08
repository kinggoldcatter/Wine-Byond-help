#!/usr/bin/env bash
# Create or reuse a stable identity outside the Wine prefix, then apply it to C:.
set -euo pipefail

# Require an existing prefix so the serial is never written to an unintended path.
if [ "$#" -ne 1 ] || [ ! -d "$1/drive_c" ]; then
    echo "Usage: $0 <existing Wine prefix>" >&2
    exit 1
fi

# Keep identity data outside the prefix so it survives a BYOND reinstall.
data_home="${XDG_DATA_HOME:-${HOME:+$HOME/.local/share}}"
if [ -z "$data_home" ] || [[ "$data_home" != /* ]]; then
    echo "Error: an absolute user data directory is required to save the BYOND identity." >&2
    exit 1
fi

state_file="$data_home/.byond-wine/MachineIdentities.conf"

if [ ! -e "$state_file" ] && [ ! -L "$state_file" ]; then
    serial=""
    # Derive a reproducible 32-bit serial from the first valid machine ID.
    # The prefix separates this hash from other uses of the same machine ID.
    for id_file in /etc/machine-id /var/lib/dbus/machine-id; do
        if [ -r "$id_file" ]; then
            machine_id="$(cat "$id_file")"
            if [[ "$machine_id" =~ ^[[:xdigit:]]{32}$ ]] && [[ ! "$machine_id" =~ ^0{32}$ ]]; then
                digest="$(printf 'byond-wine-cid-v1:%s' "${machine_id,,}" | sha256sum)"
                serial="${digest:0:8}"
                break
            fi
            echo "Warning: ignoring invalid machine ID in $id_file." >&2
        fi
    done

    # Without a machine ID, save a randomly generated serial instead.
    if [ -z "$serial" ]; then
        serial="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
        if [[ ! "$serial" =~ ^[[:xdigit:]]{8}$ ]]; then
            echo "Error: could not generate a random BYOND serial." >&2
            exit 1
        fi
    fi
    # Reserve the all-zero serial; substitute a nonzero value.
    if [ "$serial" = "00000000" ]; then
        serial="00000001"
    fi

    # Write a private temporary file, then publish it without overwriting an
    # identity created by another installer running at the same time.
    umask 077
    mkdir -p "$(dirname "$state_file")"
    temp_file="$(mktemp "${state_file}.XXXXXX")"
    trap 'rm -f -- "$temp_file"' EXIT
    printf 'volume_serial=%s\n' "${serial^^}" > "$temp_file"
    if ! ln "$temp_file" "$state_file" 2>/dev/null; then
        if [ ! -f "$state_file" ]; then
            echo "Error: cannot save BYOND serial in $state_file." >&2
            exit 1
        fi
    fi
    rm -f -- "$temp_file"
    trap - EXIT
fi

# Parse key=value data without executing it as shell code. Keep unknown keys
# available for future identity values, and reject malformed or duplicate keys.
declare -A identity=()
while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ ! "$line" =~ ^([a-z][a-z0-9_]*)=(.+)$ ]]; then
        echo "Error: invalid identity entry in $state_file." >&2
        exit 1
    fi
    key="${BASH_REMATCH[1]}"
    if [[ -v "identity[$key]" ]]; then
        echo "Error: duplicate identity key $key in $state_file." >&2
        exit 1
    fi
    identity["$key"]="${BASH_REMATCH[2]}"
done < "$state_file"

# Wine reads this file as the C: volume serial after Wine is restarted.
serial="${identity[volume_serial]:-}"
if [[ ! "$serial" =~ ^[[:xdigit:]]{8}$ ]] || [ "$serial" = "00000000" ]; then
    echo "Error: invalid or missing volume_serial in $state_file." >&2
    exit 1
fi
printf '%s\n' "${serial^^}" > "$1/drive_c/.windows-serial"
echo "Configured a stable Wine C: drive serial for BYOND."
