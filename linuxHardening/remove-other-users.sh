#!/bin/bash
#
# remove-other-users.sh
# Removes all local users except the currently logged-in user.
# Requires root. Use with caution.
#

set -e

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (e.g. sudo $0)" >&2
    exit 1
fi

CURRENT_USER="${SUDO_USER:-$USER}"
if [[ -z "$CURRENT_USER" ]]; then
    CURRENT_USER="$(whoami)"
fi

# Users we never remove (system/special)
PROTECTED_USERS="root nobody nologin sync shutdown halt daemon sys bin"
# Also skip if UID < 1000 (typical system user range on many distros).
SYSTEM_UID_MAX=999

echo "Current user (will be kept): $CURRENT_USER"
echo "Protected users (never removed): $PROTECTED_USERS"
echo ""
echo "The following users will be REMOVED (home and mail spool deleted):"
echo "---"

TO_REMOVE=()
while IFS=: read -r name _ uid _ _ home shell; do
    # Skip no name
    [[ -z "$name" ]] && continue
    # Skip current user
    [[ "$name" == "$CURRENT_USER" ]] && continue
    # Skip protected by name
    if [[ " $PROTECTED_USERS " == *" $name "* ]]; then
        continue
    fi
    # Skip system users by UID (optional safety)
    if [[ "$uid" =~ ^[0-9]+$ ]] && [[ "$uid" -le "$SYSTEM_UID_MAX" ]]; then
        echo "[SKIP] $name (uid $uid, system user)"
        continue
    fi
    TO_REMOVE+=("$name")
    echo "  - $name (uid $uid, home: $home)"
done < /etc/passwd

if [[ ${#TO_REMOVE[@]} -eq 0 ]]; then
    echo "No other users to remove."
    exit 0
fi

echo "---"
read -rp "Remove these ${#TO_REMOVE[@]} user(s)? [y/N] " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Aborted."
    exit 0
fi

for name in "${TO_REMOVE[@]}"; do
    echo "Removing user: $name"
    userdel -r "$name" 2>/dev/null || userdel "$name" || echo "Warning: could not fully remove $name" >&2
done

echo "Done."
