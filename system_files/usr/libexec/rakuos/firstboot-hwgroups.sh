#!/bin/bash
# Add first user (UID 1000) to hardware groups on first boot.
# Detects from UID, not hardcoded username — safe for any installer.
set -euo pipefail

TARGET_USER="$(getent passwd 1000 | cut -d: -f1)"

if [[ -z "$TARGET_USER" ]]; then
    echo "[rakuos-firstboot] No user with UID 1000 found, skipping."
    exit 0
fi

echo "[rakuos-firstboot] Adding $TARGET_USER to critical hardware groups..."
usermod -aG video,render,input "$TARGET_USER"
echo "[rakuos-firstboot] Done."
