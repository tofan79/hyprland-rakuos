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
  noctalia-greeter \
  ibus-mozc \
  qt6ct \
  rakuos-software-qt \
  rakuos-welcome-qt \
  systemd-oomd-defaults

## Remove conflicting DE packages
rum remove -y wofi 2>/dev/null || true

## Remove fedora wallpapers
rm -rf /usr/share/backgrounds/fedora-workstation/

## Create required system groups (fixes systemd-tmpfiles warnings)
for group in audio video input disk tty kvm render lp clock kmem sgx utmp; do
    groupadd -r "$group" 2>/dev/null || true
done

## Create greeter user for greetd
if ! id greeter &>/dev/null; then
    useradd -r -s /sbin/nologin -d /var/lib/noctalia-greeter -M greeter
fi

## Setup noctalia-greeter
if [ -x /usr/share/noctalia-greeter/setup_greeter_system.sh ]; then
    /usr/share/noctalia-greeter/setup_greeter_system.sh || true
fi

## Ensure state dir ownership (fallback if setup script didn't run)
if [ -d /var/lib/noctalia-greeter ]; then
    chown -R greeter:greeter /var/lib/noctalia-greeter
    chmod 0750 /var/lib/noctalia-greeter
fi

## Enable Services
systemctl enable greetd

## Disable problematic services on bootc/ostree
systemctl mask grub-boot-success.timer 2>/dev/null || true
systemctl mask rakuos-flatpak-watcher.service 2>/dev/null || true

## Remove problematic autostart files
rm -f /etc/xdg/autostart/nvidia-settings-user.desktop 2>/dev/null || true
