#!/bin/bash

set -ouex pipefail

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name

# Manual Hyprland identity for custom images
mkdir -p /etc/os-release.d
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    cat > /etc/os-release.d/hyprland << 'EOF'
PRETTY_NAME="RakuOS Hyprland Staging"
NAME="RakuOS"
VERSION="44 (Staging)"
ID=rakuos
ID_LIKE="fedora"
VERSION_ID=44
ANSI_COLOR="0;38;2;120;40;160"
LOGO=rakuos-logo
CPE_NAME="cpe:/o:rakuos:rakuos-hyprland-staging:44"
HOME_URL="https://rakuos.org/"
DOCUMENTATION_URL="https://rakuos.org/docs"
SUPPORT_URL="https://rakuos.org/support"
BUG_REPORT_URL="https://rakuos.org/bugs"
PLATFORM_ID="platform:f44"
VARIANT="bootc"
VARIANT_ID=hyprland-staging
VARIANT_NAME="Hyprland Staging"
EOF
else
    cat > /etc/os-release.d/hyprland << 'EOF'
PRETTY_NAME="RakuOS Hyprland"
NAME="RakuOS"
VERSION="44"
ID=rakuos
ID_LIKE="fedora"
VERSION_ID=44
ANSI_COLOR="0;38;2;120;40;160"
LOGO=rakuos-logo
CPE_NAME="cpe:/o:rakuos:rakuos-hyprland:44"
HOME_URL="https://rakuos.org/"
DOCUMENTATION_URL="https://rakuos.org/docs"
SUPPORT_URL="https://rakuos.org/support"
BUG_REPORT_URL="https://rakuos.org/bugs"
PLATFORM_ID="platform:f44"
VARIANT="bootc"
VARIANT_ID=hyprland
VARIANT_NAME="Hyprland"
EOF
fi
