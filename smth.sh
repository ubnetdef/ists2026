#!/usr/bin/env bash

# Usage:
#   sudo ./set_login_grace_time.sh 20
#   sudo ./set_login_grace_time.sh 30s
#   sudo ./set_login_grace_time.sh 1m

set -e

CONFIG="/etc/ssh/sshd_config"

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (use sudo)."
  exit 1
fi

if [[ -z "$1" ]]; then
  echo "Usage: sudo $0 <time>"
  echo "Examples: 20   30s   1m"
  exit 1
fi

NEW_VALUE="$1"

echo "🔹 Backing up sshd_config..."
cp "$CONFIG" "${CONFIG}.bak.$(date +%F-%H%M%S)"

echo "🔹 Setting LoginGraceTime to $NEW_VALUE ..."

if grep -qE '^[#]*\s*LoginGraceTime' "$CONFIG"; then
  # Replace existing (commented or uncommented) line
  sed -i -E "s|^[#]*\s*LoginGraceTime.*|LoginGraceTime ${NEW_VALUE}|g" "$CONFIG"
else
  # Add if not present
  echo "LoginGraceTime ${NEW_VALUE}" >> "$CONFIG"
fi

echo "🔹 Validating SSH configuration..."
if sshd -t; then
  echo "✅ Configuration valid."
else
  echo "❌ sshd config test failed. Restoring backup."
  cp "${CONFIG}.bak."* "$CONFIG"
  exit 1
fi

echo "🔹 Reloading SSH service..."
if systemctl is-active --quiet sshd; then
  systemctl reload sshd
elif systemctl is-active --quiet ssh; then
  systemctl reload ssh
else
  echo "⚠️ Could not detect SSH service name. Please reload manually."
fi

echo "🎉 LoginGraceTime successfully updated to ${NEW_VALUE}"
