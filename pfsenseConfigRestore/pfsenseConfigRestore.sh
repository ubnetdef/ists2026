#!/bin/sh

CONFIG="/cf/conf/config.xml"
SNAPSHOT="/root/config_snapshot.xml"
INTERVAL=60  # seconds between restore checks

# Take the initial snapshot only if one doesn't already exist
if [ -f "$SNAPSHOT" ]; then
    echo "Snapshot already exists at $SNAPSHOT, skipping backup."
else
    echo "Taking snapshot of current config..."
    cp "$CONFIG" "$SNAPSHOT"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to take snapshot"
        exit 1
    fi

    echo "Snapshot saved to $SNAPSHOT"
fi

echo "Starting restore loop every $INTERVAL seconds. Ctrl+C to stop."

# Continuously restore
while true; do
    cp "$SNAPSHOT" "$CONFIG"
    /etc/rc.reload_all > /dev/null 2>&1
    echo "$(date): Config restored from snapshot"
    sleep $INTERVAL
done