#!/usr/bin/env bash
set -uo pipefail

# Prefix-scoped BYOND process watchdog.
# Run it as a Lutris pre-launch command without waiting for it. It waits for a
# BYOND process to appear, then watches that prefix until all matching BYOND
# processes exit and closes the configured Edge/WebView processes.
# Process discovery and termination use Windows tools inside the prefix;
# reported Windows PIDs are not Linux host PIDs.

# Configuration: all time values are seconds. The startup timeout starts when
# the watchdog launches; the other timeouts apply during cleanup.
POLL_INTERVAL_SECONDS=2
START_TIMEOUT_SECONDS=300
CLOSE_TIMEOUT_SECONDS=3
FORCE_VERIFY_TIMEOUT_SECONDS=3
# Set this to a runner executable when automatic detection is unsuitable.
# Otherwise, the script checks WINE and then detects the runner beside the
# wineserver associated with the selected prefix.
WINE_BIN_OVERRIDE=""
# Image names are matched case-insensitively against tasklist output.
BYOND_PROCESS_NAMES=(byond.exe dreamseeker.exe dreamdaemon.exe dreammaker.exe)
EDGE_PROCESS_NAMES=(msedge.exe msedgewebview2.exe microsoftedgeupdate.exe)

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

log_pids() {
    local message="$1" pid pid_list=""
    shift
    if [ "$#" -eq 0 ]; then
        log "$message: none"
        return
    fi
    for pid in "$@"; do
        [ -n "$pid_list" ] && pid_list+=", "
        pid_list+="$pid"
    done
    log "$message: $pid_list"
}

usage() {
    printf 'Usage: %s [--prefix PATH]\n' "$0"
    printf 'Waits for BYOND in the prefix process table, then closes matching Edge/WebView processes.\n'
    printf 'Prefix precedence: --prefix, WINEPREFIX, PROTON_PREFIX, STEAM_COMPAT_DATA_PATH/pfx, script directory.\n'
    printf 'The runner is selected from WINE_BIN_OVERRIDE, WINE, or the prefix wineserver.\n'
}

explicit_prefix=""
case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    --prefix)
        if [ "$#" -ne 2 ] || [ -z "$2" ]; then
            usage >&2
            exit 2
        fi
        explicit_prefix="$2"
        ;;
    "")
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

canonical_prefix() {
    local path="$1"
    [ -n "$path" ] || return 1
    readlink -f -- "$path" 2>/dev/null
}

script_path="$(readlink -f -- "$0")" || {
    printf 'Error: cannot resolve script path: %s\n' "$0" >&2
    exit 1
}
script_dir="$(dirname -- "$script_path")"

runner_prefix=""
prefix_source=""
# Select the prefix in this order: explicit option, Wine/Proton environment,
# Steam compatibility data, then the directory containing this script.
if [ -n "$explicit_prefix" ]; then
    runner_prefix="$explicit_prefix"
    prefix_source="--prefix argument"
elif [ -n "${WINEPREFIX:-}" ]; then
    runner_prefix="$WINEPREFIX"
    prefix_source="WINEPREFIX"
elif [ -n "${PROTON_PREFIX:-}" ]; then
    runner_prefix="$PROTON_PREFIX"
    prefix_source="PROTON_PREFIX"
elif [ -n "${STEAM_COMPAT_DATA_PATH:-}" ]; then
    runner_prefix="$STEAM_COMPAT_DATA_PATH/pfx"
    prefix_source="STEAM_COMPAT_DATA_PATH"
else
    runner_prefix="$script_dir"
    prefix_source="script directory"
fi

if [ -n "$runner_prefix" ]; then
    target_prefix="$(canonical_prefix "$runner_prefix")" || {
        log "ERROR: cannot resolve prefix: $runner_prefix" >&2
        exit 1
    }
    [ -d "$target_prefix" ] || {
        log "ERROR: prefix is not a directory: $target_prefix" >&2
        exit 1
    }
else
    target_prefix=""
fi

read_process_environment() {
    local pid="$1" entry
    proc_wineprefix=""
    proc_compat=""
    # /proc/PID/environ is NUL-delimited, so read each variable separately.
    while IFS= read -r -d '' entry; do
        case "$entry" in
            WINEPREFIX=*) proc_wineprefix="${entry#WINEPREFIX=}" ;;
            STEAM_COMPAT_DATA_PATH=*) proc_compat="${entry#STEAM_COMPAT_DATA_PATH=}" ;;
            PROTON_PREFIX=*) [ -n "$proc_wineprefix" ] || proc_wineprefix="${entry#PROTON_PREFIX=}" ;;
        esac
    done < "/proc/$pid/environ" 2>/dev/null
}

process_prefix() {
    if [ -n "$proc_wineprefix" ]; then
        canonical_prefix "$proc_wineprefix"
    elif [ -n "$proc_compat" ]; then
        canonical_prefix "$proc_compat/pfx"
    fi
}

find_runner_wine() {
    local proc pid executable candidate found_prefix
    # Match the wineserver by its prefix environment, not just by executable
    # name, so a different running Wine prefix cannot select the runner.
    for proc in /proc/[0-9]*; do
        [ -d "$proc" ] || continue
        pid="${proc##*/}"
        read_process_environment "$pid"
        found_prefix="$(process_prefix)" || continue
        [ "$found_prefix" = "$target_prefix" ] || continue

        executable="$(readlink -f -- "/proc/$pid/exe" 2>/dev/null)" || continue
        case "${executable##*/}" in
            wineserver|wineserver64) ;;
            *) continue ;;
        esac

        # Use the runner paired with this wineserver. This also accommodates
        # runners that expose a Wine-compatible binary beside wineserver.
        candidate="$(dirname -- "$executable")/wine"
        [ -x "$candidate" ] || candidate="$(dirname -- "$executable")/wine64"
        [ -x "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done
    return 1
}

resolve_wine_binary() {
    local requested="$1"
    if [[ "$requested" == */* ]]; then
        [ -x "$requested" ] || return 1
        readlink -f -- "$requested"
    else
        command -v -- "$requested"
    fi
}

matching_process_name() {
    local image="${1,,}" name
    shift
    for name in "$@"; do
        [ "$image" = "$name" ] && { printf '%s\n' "$name"; return 0; }
    done
    return 1
}

scan_prefix_processes() {
    local output status image_field pid_field remainder image pid name
    byond_pids=()
    edge_pids=()

    # tasklist runs inside the selected prefix, so its Windows process list
    # excludes host-side Lutris wrappers. Its CSV PIDs are used with taskkill.
    output="$(WINEPREFIX="$target_prefix" WINEDEBUG="${WINEDEBUG:--all}" \
        "$wine_bin" "$tasklist_exe" /fo csv /nh 2>&1)"
    status=$?
    if [ "$status" -ne 0 ]; then
        log "ERROR: tasklist failed with status $status: $output" >&2
        return 1
    fi

    while IFS=',' read -r image_field pid_field remainder; do
        image="${image_field#\"}"
        image="${image%\"}"
        pid="${pid_field#\"}"
        pid="${pid%\"}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue

        name="$(matching_process_name "$image" "${BYOND_PROCESS_NAMES[@]}")" || name=""
        if [ -n "$name" ]; then
            byond_pids+=("$pid")
        fi

        name="$(matching_process_name "$image" "${EDGE_PROCESS_NAMES[@]}")" || name=""
        if [ -n "$name" ]; then
            edge_pids+=("$pid")
        fi
    done <<< "$output"
}

taskkill_process() {
    local pid="$1" force="${2:-}" output status
    # Graceful and forced requests target the Windows PID from tasklist.
    if [ -n "$force" ]; then
        output="$(WINEPREFIX="$target_prefix" WINEDEBUG="${WINEDEBUG:--all}" \
            "$wine_bin" "$taskkill_exe" /F /PID "$pid" 2>&1)"
    else
        output="$(WINEPREFIX="$target_prefix" WINEDEBUG="${WINEDEBUG:--all}" \
            "$wine_bin" "$taskkill_exe" /PID "$pid" 2>&1)"
    fi
    status=$?
    if [ "$status" -eq 0 ]; then
        return 0
    fi
    taskkill_error_status="$status"
    taskkill_error_output="$output"
    return "$status"
}

tasklist_exe="$target_prefix/drive_c/windows/system32/tasklist.exe"
taskkill_exe="$target_prefix/drive_c/windows/system32/taskkill.exe"
for executable in "$tasklist_exe" "$taskkill_exe"; do
    [ -x "$executable" ] || {
        log "ERROR: required prefix tool is missing or not executable: $executable" >&2
        exit 1
    }
done

requested_wine="${WINE_BIN_OVERRIDE:-${WINE:-}}"
if [ -n "$requested_wine" ]; then
    wine_bin="$(resolve_wine_binary "$requested_wine")" || {
        log "ERROR: cannot resolve Wine runner executable: $requested_wine" >&2
        exit 1
    }
    wine_source="configured runner executable"
else
    wine_bin=""
    wine_source="matching wineserver"
fi

log "Watchdog starting (PID $$)."
log "Using prefix $target_prefix (source: $prefix_source)."
log "Settings: poll=${POLL_INTERVAL_SECONDS}s, startup timeout=${START_TIMEOUT_SECONDS}s, graceful close timeout=${CLOSE_TIMEOUT_SECONDS}s, force verification timeout=${FORCE_VERIFY_TIMEOUT_SECONDS}s."
log "Wine runner source: $wine_source."
log "Waiting for BYOND in this prefix's Wine/proton process list."

# Wait for BYOND to launch. If it never appears before the deadline, exit
# without running cleanup; this avoids treating a slow launch as a game exit.
start_deadline=$((SECONDS + START_TIMEOUT_SECONDS))
runner_reported=0
while :; do
    if [ -z "$wine_bin" ]; then
        wine_bin="$(find_runner_wine 2>/dev/null || true)"
        if [ -n "$wine_bin" ] && [ "$runner_reported" -eq 0 ]; then
            log "Found runner executable from this prefix's wineserver: $wine_bin."
            runner_reported=1
        fi
    fi

    if [ -n "$wine_bin" ]; then
        scan_prefix_processes || exit 1
        [ "${#byond_pids[@]}" -gt 0 ] && break
    fi

    if [ "$SECONDS" -ge "$start_deadline" ]; then
        log "ERROR: no matching BYOND process found within $START_TIMEOUT_SECONDS seconds." >&2
        exit 1
    fi
    sleep "$POLL_INTERVAL_SECONDS"
done

log "Monitoring Wine/proton processes reported by this prefix's tasklist."
last_byond_state="__not_logged__"
while :; do
    scan_prefix_processes || exit 1
    current_byond_state="${byond_pids[*]}"
    if [ "$current_byond_state" != "$last_byond_state" ]; then
        log_pids "BYOND PIDs" "${byond_pids[@]}"
        last_byond_state="$current_byond_state"
    fi
    [ "${#byond_pids[@]}" -gt 0 ] || break
    sleep "$POLL_INTERVAL_SECONDS"
done

# BYOND is considered closed only when none of the configured image names
# remain in tasklist. Take a fresh scan so cleanup targets current Edge PIDs.
log "No matching BYOND processes remain in $target_prefix."
scan_prefix_processes || exit 1
if [ "${#edge_pids[@]}" -eq 0 ]; then
    log "No matching Edge/WebView processes found; cleanup is complete."
    exit 0
fi
log_pids "Edge/webview PIDs found" "${edge_pids[@]}"
log_pids "Requesting graceful termination of Edge/WebView PIDs" "${edge_pids[@]}"
taskkill_failures=()
# Send requests sequentially, then give every remaining process the full
# graceful timeout before escalating.
for pid in "${edge_pids[@]}"; do
    if ! taskkill_process "$pid"; then
        taskkill_failures+=("$pid (status $taskkill_error_status)")
        last_taskkill_error="$taskkill_error_output"
    fi
done

scan_prefix_processes || exit 1
if [ "${#edge_pids[@]}" -eq 0 ]; then
    log "No Edge/WebView PIDs remain after the close request."
    exit 0
fi
if [ "${#taskkill_failures[@]}" -gt 0 ]; then
    log "WARNING: graceful taskkill failed for ${taskkill_failures[*]}: $last_taskkill_error" >&2
fi
log_pids "Waiting up to ${CLOSE_TIMEOUT_SECONDS}s for PIDs" "${edge_pids[@]}"
for ((elapsed = 0; elapsed < CLOSE_TIMEOUT_SECONDS; elapsed++)); do
    sleep 1
    scan_prefix_processes || exit 1
    if [ "${#edge_pids[@]}" -eq 0 ]; then
        log "All matching Edge/WebView processes exited within the close timeout."
        exit 0
    fi
    log_pids "Still running after $((elapsed + 1))s, PIDs" "${edge_pids[@]}"
done

scan_prefix_processes || exit 1
if [ "${#edge_pids[@]}" -eq 0 ]; then
    log "All matching Edge/WebView processes exited within the close timeout."
    exit 0
fi
log_pids "WARNING: Edge/webview PIDs still active after ${CLOSE_TIMEOUT_SECONDS}s" "${edge_pids[@]}" >&2
log_pids "Force-closing remaining Edge/webview PIDs" "${edge_pids[@]}"
force_taskkill_failures=()
# Escalate only the Edge/WebView PIDs still present in the latest scan.
for pid in "${edge_pids[@]}"; do
    if ! taskkill_process "$pid" force; then
        force_taskkill_failures+=("$pid (status $taskkill_error_status)")
        last_taskkill_error="$taskkill_error_output"
    fi
done

for ((elapsed = 0; elapsed < FORCE_VERIFY_TIMEOUT_SECONDS; elapsed++)); do
    sleep 1
    scan_prefix_processes || exit 1
    if [ "${#edge_pids[@]}" -eq 0 ]; then
        log "All matching Edge/WebView processes exited after force-close."
        exit 0
    fi
    log_pids "Still running after force-close ($((elapsed + 1))s), PIDs" "${edge_pids[@]}"
done

scan_prefix_processes || exit 1
if [ "${#edge_pids[@]}" -gt 0 ]; then
    if [ "${#force_taskkill_failures[@]}" -gt 0 ]; then
        log "ERROR: forced taskkill failed for ${force_taskkill_failures[*]}: $last_taskkill_error" >&2
    fi
    log_pids "ERROR: Edge/webview PIDs remain after force-close" "${edge_pids[@]}" >&2
    exit 1
fi
log "All matching Edge/WebView processes exited after force-close."