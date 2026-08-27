#!/bin/bash

set -ouex pipefail

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name
BUILD_DATE=$(date -u +%Y%m%d)
BUILD_VERSION=$(date -u +%Y.%m.%d)
FEDORA_VERSION=$(rpm -E %fedora)

cat > /usr/lib/os-release << EOF
NAME="RakuOS Hyprland"
VERSION="${BUILD_VERSION} (Hyprland Rolling x86_64)"
ID=rakuos
ID_LIKE="fedora"
VERSION_ID="${FEDORA_VERSION}"
PLATFORM_ID="platform:f${FEDORA_VERSION}"
PRETTY_NAME="RakuOS Hyprland Rolling x86_64 [${BUILD_DATE}]"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=rakuos-logo-icon
HOME_URL="https://rakuos.org"
DOCUMENTATION_URL="https://docs.rakuos.org"
SUPPORT_URL="https://rakuos.org/support"
BUG_REPORT_URL="https://github.com/RakuOS/rakuos/issues"
PRIVACY_POLICY_URL="https://rakuos.org/privacy"
VARIANT="Hyprland"
VARIANT_ID=hyprland
EOF
