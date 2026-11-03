#!/system/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Local TA extension for Tricky Store OSS target.txt.
MODDIR=${0%/*}
BB=/data/adb/ksu/bin/busybox
ROOT=/data/adb/tricky_store
PACKAGES=/data/system/packages.list
ENGINE=/data/adb/modules/tricky_store
STATE="$ROOT/ta-targets-local"
TARGET="$ROOT/target.txt"
SETTINGS="$STATE/settings.conf"
BACKUP="$STATE/target.original.txt"

[ -x "$BB" ] || { echo "KernelSU BusyBox unavailable" >&2; exit 1; }
umask 077
"$BB" mkdir -p "$STATE" || exit 1

read_settings() {
    MODE=generate
    AUTO_ADD=1
    [ -f "$SETTINGS" ] || return 0
    while IFS='=' read -r key value; do
        case "$key:$value" in
            mode:auto|mode:generate|mode:hack) MODE=$value ;;
            auto_add:0|auto_add:1) AUTO_ADD=$value ;;
        esac
    done < "$SETTINGS"
}

write_settings() {
    printf 'mode=%s\nauto_add=%s\n' "$MODE" "$AUTO_ADD" > "$STATE/settings.next" || return 1
    "$BB" mv -f "$STATE/settings.next" "$SETTINGS"
}

supported_engine() {
    [ -f "$ENGINE/module.prop" ] &&
        "$BB" grep -q '^name=.*OSS' "$ENGINE/module.prop"
}

write_status() {
    count=0
    [ ! -f "$TARGET" ] || count=$("$BB" awk '
        { sub(/#.*/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); sub(/[!?]$/, ""); gsub(/^[ \t]+|[ \t]+$/, "") }
        /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$/ { n++ }
        END { print n+0 }' "$TARGET")
    backup=false
    [ ! -f "$BACKUP" ] || backup=true
    supported=false
    supported_engine && supported=true
    auto=false
    [ "$AUTO_ADD" != 1 ] || auto=true
    synced=''
    [ ! -f "$STATE/last-sync" ] || synced=$("$BB" cat "$STATE/last-sync")
    printf '{"mode":"%s","auto_add":%s,"target_count":%s,"backup":%s,"supported":%s,"last_sync":"%s"}\n' \
        "$MODE" "$auto" "$count" "$backup" "$supported" "$synced"
}

merge_targets() {
    bulk=$1
    supported_engine || { echo "This extension requires Tricky Store OSS" >&2; return 1; }
    [ ! -e "$ENGINE/disable" ] && [ ! -e "$ENGINE/remove" ] || return 0
    [ -r "$PACKAGES" ] && [ -s "$PACKAGES" ] || { echo "Installed package list unavailable; targets preserved" >&2; return 1; }
    candidate="$STATE/target.next"
    input="$TARGET"
    if [ -f "$TARGET" ]; then
        "$BB" cp -p "$TARGET" "$candidate" || return 1
    else
        input="$STATE/empty-target"
        : > "$input"
    fi
    "$BB" awk -v mode="$MODE" -v bulk="$bulk" -f "$MODDIR/target-merge.awk" \
        "$input" "$PACKAGES" > "$candidate" || { echo "Package list empty or unreadable; targets preserved" >&2; return 1; }
    if [ ! -f "$BACKUP" ]; then
        "$BB" cp -p "$input" "$BACKUP" || return 1
    fi
    if [ "$bulk" = 1 ] && [ -f "$TARGET" ]; then
        snapshot=$("$BB" mktemp "$STATE/target.before-bulk.XXXXXX") || return 1
        "$BB" cp -p "$TARGET" "$snapshot" || return 1
    fi
    if ! "$BB" cmp -s "$candidate" "$TARGET"; then
        "$BB" mv -f "$candidate" "$TARGET" || return 1
    fi
    "$BB" touch "$STATE/initialized"
    "$BB" date '+%Y-%m-%d %H:%M:%S' > "$STATE/last-sync"
}

case "${1:-status}" in
    daemon)
        exec "$BB" flock -n "$STATE/daemon.lock" "$BB" sh "$0" loop
        ;;
    loop)
        while [ -f "$MODDIR/target-automation.sh" ] &&
              [ ! -e "$MODDIR/disable" ] && [ ! -e "$MODDIR/remove" ]; do
            "$BB" sh "$0" sync >/dev/null 2>&1
            "$BB" sleep 60
        done
        exit 0
        ;;
esac

if [ "${1:-}" != locked ]; then
    [ "$#" -gt 0 ] || set -- status
    exec "$BB" flock -x "$STATE/write.lock" "$BB" sh "$0" locked "$@"
fi
shift
read_settings
case "${1:-status}" in
    status) ;;
    configure)
        case "${2:-}" in auto|generate|hack) MODE=$2 ;; *) exit 2 ;; esac
        case "${3:-}" in 0|1) AUTO_ADD=$3 ;; *) exit 2 ;; esac
        write_settings || exit 1
        if [ "$AUTO_ADD" = 1 ]; then
            bulk=0
            [ -e "$STATE/initialized" ] || bulk=1
            merge_targets "$bulk" || exit 1
        fi
        ;;
    sync)
        [ "$AUTO_ADD" = 1 ] || { write_status; exit 0; }
        [ -f "$SETTINGS" ] || write_settings || exit 1
        bulk=0
        [ -e "$STATE/initialized" ] || bulk=1
        merge_targets "$bulk" || exit 1
        ;;
    apply)
        case "${2:-}" in auto|generate|hack) MODE=$2 ;; *) exit 2 ;; esac
        write_settings || exit 1
        merge_targets 1 || exit 1
        ;;
    restore)
        [ -f "$BACKUP" ] || { echo "No original target backup" >&2; exit 1; }
        AUTO_ADD=0
        write_settings || exit 1
        if [ -f "$TARGET" ]; then
            snapshot=$("$BB" mktemp "$STATE/target.before-restore.XXXXXX") || exit 1
            "$BB" cp -p "$TARGET" "$snapshot" || exit 1
        fi
        "$BB" cp -p "$BACKUP" "$STATE/target.restore" || exit 1
        "$BB" mv -f "$STATE/target.restore" "$TARGET" || exit 1
        ;;
    *) exit 2 ;;
esac
write_status
