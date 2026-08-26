#!/bin/bash

set -ouex pipefail

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name
BUILD_DATE=$(date -u +%Y%m%d)
BUILD_VERSION=$(date -u +%Y.%m.%d)

cat > /usr/lib/os-release << EOF
NAME="RakuOS Hyprland Rolling"
VERSION="${BUILD_VERSION} (${BUILD_DATE})"
PRETTY_NAME="RakuOS Hyprland x86_64 [${BUILD_DATE}]"
...
EOF
