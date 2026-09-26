#!/bin/bash

set -ouex pipefail

# Terra stays enabled here on purpose: the overlay prebake in
# post-build-overlay.sh still resolves packages.list, which pulls browser
# packages from Terra. It is disabled again at the end of that script.

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name

# Manual Hyprland identity for custom images.
# Always "Staging": the base image consumed by this build is the RakuOS
# staging tree (rakuos-base-*:staging), so the branding must match it —
# silently labelling the deploy as stable would be misleading. The default
# `staging` base tag is what the workflow ships by default. If a real stable
# base is ever used, flip these values to the stable variant.
mkdir -p /etc/os-release.d
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

# Override the uwsm session entry AFTER rum install (the hyprland-uwsm RPM
# owns /usr/share/wayland-sessions/hyprland-uwsm.desktop and would clobber a
# plain COPY). /usr/local is a symlink to /var/usrlocal in the base image, so
# it cannot be used as a COPY destination either — rewriting here is the only
# reliable spot. UWSM_SILENT_START=2 stops uwsm start from printing its
# progress to stdout (the display manager forwards it to the VT, showing text
# between the greeter and Hyprland); real errors still surface via syslog/journal.
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/hyprland-uwsm.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=An intelligent dynamic tiling Wayland compositor
Exec=env UWSM_SILENT_START=2 uwsm start -e -D Hyprland hyprland.desktop
TryExec=uwsm
DesktopNames=Hyprland
Type=Application
EOF
