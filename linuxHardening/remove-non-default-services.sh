#!/usr/bin/env bash
#
# remove-non-default-services.sh
# Disables and stops all enabled systemd services that are not in the
# default/whitelist. Requires root. Use with caution.
#
# Edit the WHITELIST below or set WHITELIST_FILE to use an external list.
#

set -e

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (e.g. sudo $0)" >&2
    exit 1
fi

# Optional: path to a file with one service name (or pattern) per line.
# If set, this file is used instead of the built-in whitelist.
# Lines starting with # and empty lines are ignored.
WHITELIST_FILE="${WHITELIST_FILE:-}"

# Built-in whitelist: services considered "default" and left enabled.
# Add or remove names to match your system. Patterns are matched with grep -E.
# Example: "ssh" matches ssh.service, sshd.service.
WHITELIST_DEFAULT=(
    dbus
    getty
    ssh
    sshd
    systemd
    user@
    systemd-logind
    systemd-networkd
    systemd-resolved
    systemd-timesyncd
    NetworkManager
    cron
    rsyslog
    polkit
    udisks2
    colord
    fwupd
    accounts-daemon
    avahi-daemon
    bluetooth
    cups
    gdm
    lightdm
    sddm
)

# Build the whitelist: from file if set, otherwise use default array.
WHITELIST_PATTERNS=()
if [[ -n "$WHITELIST_FILE" ]] && [[ -r "$WHITELIST_FILE" ]]; then
    echo "Using whitelist from: $WHITELIST_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        WHITELIST_PATTERNS+=("$line")
    done < "$WHITELIST_FILE"
else
    WHITELIST_PATTERNS=("${WHITELIST_DEFAULT[@]}")
fi

# Check if a service name matches any whitelist pattern.
is_whitelisted() {
    local name="$1"
    local pat
    for pat in "${WHITELIST_PATTERNS[@]}"; do
        if [[ "$name" == *"$pat"* ]]; then
            return 0
        fi
    done
    return 1
}

echo "Whitelist patterns: ${WHITELIST_PATTERNS[*]}"
echo ""
echo "The following enabled services are NOT in the whitelist and will be DISABLED and STOPPED:"
echo "---"

TO_DISABLE=()
while read -r unit _; do
    [[ -z "$unit" ]] && continue
    # Strip .service if present for display; we pass full name to systemctl
    if is_whitelisted "$unit"; then
        continue
    fi
    TO_DISABLE+=("$unit")
    echo "  - $unit"
done < <(systemctl list-unit-files --type=service --state=enabled --no-legend --no-pager | awk '{print $1}')

if [[ ${#TO_DISABLE[@]} -eq 0 ]]; then
    echo "No non-whitelisted enabled services found."
    exit 0
fi

echo "---"
read -rp "Disable and stop these ${#TO_DISABLE[@]} service(s)? [y/N] " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Aborted."
    exit 0
fi

for unit in "${TO_DISABLE[@]}"; do
    echo "Disabling and stopping: $unit"
    systemctl stop "$unit" 2>/dev/null || true
    systemctl disable "$unit" 2>/dev/null || true
done

echo "Done."
