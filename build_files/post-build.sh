#!/bin/bash

set -ouex pipefail

# Disable Terra again — build.sh only enabled it temporarily for the install
# step above; third-party repos ship disabled by default.
rum config-manager --set-disabled terra

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "kineticwe" > /usr/share/rakuos/de-name

# Manual KineticWE identity for custom images.
# Always "Staging": the base image consumed by this build is the RakuOS
# staging tree (rakuos-base-*:staging), so the branding must match it —
# silently labelling the deploy as stable would be misleading. The default
# `staging` base tag is what the workflow ships by default. If a real stable
# base is ever used, flip these values to the stable variant.
mkdir -p /etc/os-release.d
cat > /etc/os-release.d/kineticwe << 'EOF'
PRETTY_NAME="RakuOS KineticWE Staging"
NAME="RakuOS"
VERSION="44 (Staging)"
ID=rakuos
ID_LIKE="fedora"
VERSION_ID=44
ANSI_COLOR="0;38;2;120;40;160"
LOGO=rakuos-logo
CPE_NAME="cpe:/o:rakuos:rakuos-kineticwe-staging:44"
HOME_URL="https://rakuos.org/"
DOCUMENTATION_URL="https://rakuos.org/docs"
SUPPORT_URL="https://rakuos.org/support"
BUG_REPORT_URL="https://rakuos.org/bugs"
PLATFORM_ID="platform:f44"
VARIANT="bootc"
VARIANT_ID=kineticwe-staging
VARIANT_NAME="KineticWE Staging"
EOF
