#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PACKAGES_LIST="/usr/share/rakuos/packages.list"
FACTORY_VAR_ROOT="/usr/share/factory/var"
PACKAGES_LIST="$FACTORY_VAR_ROOT/lib/rakuos/packages.list"
UPPER_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/upper"
WORK_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/work"
STATE_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.state"
DIRTY_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.dirty"

echo "[rakuos] Seeding overlay state for first-boot install..."

mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR"
mkdir -p "$WORK_DIR"

if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    echo "[rakuos] packages.list seeded."
else
    touch "$PACKAGES_LIST"
    echo "[rakuos] Empty packages.list created."
fi

rm -f "$STATE_FILE" "$DIRTY_FILE"
sed -i -e '$a\' "$PACKAGES_LIST" 2>/dev/null || true

cat >> /usr/share/rakuos/protected-packages.txt << 'PKGLIST'
hyprland
hyprland-guiutils
noctalia-git
uwsm
kitty
kitty-shell-integration
kitty-terminfo
neovim
pipewire
pipewire-alsa
wireplumber
xdg-desktop-portal
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
wl-clipboard
egl-wayland
grim
slurp
wtype
gnome-keyring
gnome-keyring-pam
fprintd-pam
adw-gtk3-theme
gvfs
gvfs-mtp
gvfs-nfs
pavucontrol
nm-connection-editor
NetworkManager-adsl
NetworkManager-bluetooth
NetworkManager-ppp
NetworkManager-wwan
power-profiles-daemon
asusctl
libnotify
noctalia-greeter
ibus-mozc
qt6ct
rakuos-software-qt
rakuos-welcome-qt
systemd-oomd-defaults
PKGLIST

if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json
fi

echo "[rakuos] Post-build seed complete."
