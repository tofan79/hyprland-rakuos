#!/bin/bash

set -ouex pipefail

# Enable COPR for Hyprland and Noctalia
dnf -y copr enable lionheartp/Hyprland
dnf -y copr enable mindset/Mindset-Apps

# Set priority for COPR repos (higher priority than Terra/RPM Fusion)
# COPR repos are enabled last, so they're already highest priority by default

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS Hyprland Staging".
RAKUOS_RELEASE_PKG="rakuos-release-hyprland"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-hyprland-staging"
fi

## Install packages
rum install -y \
  hyprland \
  hyprland-guiutils \
  noctalia-git \
  uwsm \
  kitty \
  kitty-shell-integration \
  kitty-terminfo \
  mpv \
  neovim \
  nautilus \
  loupe \
  pipewire \
  pipewire-alsa \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  wl-clipboard \
  egl-wayland \
  hyprpicker \
  cliphist \
  brightnessctl \
  playerctl \
  grim \
  slurp \
  swappy \
  wtype \
  blueman \
  gnome-keyring \
  gnome-keyring-pam \
  fprintd-pam \
  adw-gtk3-theme \
  gnome-calculator \
  gnome-disk-utility \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  pavucontrol \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  tuned \
  tuned-ppd \
  libnotify \
  sddm \
  ibus-mozc \
  qt6ct \
  rakuos-software-qt \
  rakuos-welcome-qt \
  systemd-oomd-defaults

## Remove conflicting DE packages
rum remove -y swaylock alacritty fuzzel waybar wofi 2>/dev/null || true

## Remove fedora wallpapers
rm -rf /usr/share/backgrounds/fedora-workstation/

## Enable Services
systemctl enable sddm
