#!/bin/bash

set -ouex pipefail

# Source os-release so VERSION_ID is available (set -u is active)
[ -f /etc/os-release ] && . /etc/os-release || VERSION_ID="$(rpm -q --qf '%{VERSION}' fedora-release 2>/dev/null || echo 40)"

# Enable COPR for Hyprland and Noctalia
dnf -y copr enable lionheartp/Hyprland
dnf -y copr enable mindset/Mindset-Apps

# Pin COPRs at priority=20: below RakuOS repos (v4=5, v3=10), above defaults.
# Matches RakuOS base's convention of editing repo files directly with sed.
# Remove any pre-existing priority line (e.g. baked in by copr enable) first.
for _copr_repo in "mindset:Mindset-Apps" "lionheartp:Hyprland"; do
    _copr_id="${_copr_repo%%:*}"            # mindset / lionheartp
    _copr_name="${_copr_repo#*:}"           # Mindset-Apps / Hyprland
    _copr_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${_copr_repo}.repo"
    sed -i '/^priority=/d' "$_copr_file"
    sed -i '/^\[copr:copr.fedorainfracloud.org:'"$_copr_id"':'"$_copr_name"'\]/a priority=20' "$_copr_file"
done

# NOTE: rakuos-release-hyprland package not available yet in repos
# When available, uncomment below:
# RAKUOS_RELEASE_PKG="rakuos-release-hyprland"
# if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
#     RAKUOS_RELEASE_PKG="rakuos-release-hyprland-staging"
# fi

## Remove tuned first
# Auto-fix: Terra (Fyralabs) rotated its signing keys - refresh bundled keys so
# repo metadata verification doesn't fail with stale RPM-GPG-KEY-terra files.
rum install -y fedora-gpg-keys 2>/dev/null || true
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${VERSION_ID}-primary 2>/dev/null || true
for _suffix in "" "-source" "-extras" "-extras-source" "-mesa" "-mesa-source" "-multimedia" "-multimedia-source" "-nvidia" "-nvidia-source"; do
    curl -fsSL "https://repos.fyralabs.com/terra${VERSION_ID}${_suffix}/key.asc" \
        -o "/etc/pki/rpm-gpg/RPM-GPG-KEY-terra${VERSION_ID}${_suffix}" 2>/dev/null || true
done
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra${VERSION_ID}* 2>/dev/null || true

# Last-resort fallback: disable GPG check for Terra if the refreshed key fails
if ! dnf -y install --refresh terra-release 2>/dev/null; then
    echo "::warning::Terra GPG recovery needed, disabling GPG check for terra repo..."
    dnf config-manager --save --setopt terra.gpgcheck=0 2>/dev/null || true
    sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/terra.repo 2>/dev/null || true
fi

rum remove -y tuned tuned-ppd 2>/dev/null || true

## Install packages
rum install -y --refresh \
  hyprland \
  hyprland-guiutils \
  noctalia-git \
  uwsm \
  kitty \
  kitty-shell-integration \
  kitty-terminfo \
  neovim \
  pipewire \
  pipewire-alsa \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  wl-clipboard \
  egl-wayland \
  grim \
  slurp \
  wtype \
  gnome-keyring \
  gnome-keyring-pam \
  fprintd-pam \
  adw-gtk3-theme \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  pavucontrol \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  power-profiles-daemon \
  libnotify \
  noctalia-greeter-git \
  ibus-mozc \
  qt6ct \
  rakuos-software-qt \
  rakuos-welcome-qt \
  systemd-oomd-defaults \
  ethtool \
  python3-pyudev \
  python3-inotify \
  virt-what

## Remove wofi and tuned configs
rum remove -y wofi 2>/dev/null || true
rm -rf /etc/tuned /usr/lib/tuned 2>/dev/null || true

## Remove heavy dev dependencies not needed for desktop
rum remove -y tree-sitter-cli nodejs22 nodejs22-libs nodejs22-bin nodejs22-docs nodejs22-full-i18n nodejs22-npm nodejs22-npm-bin 2>/dev/null || true

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
systemctl enable rakuos-firstboot.service

## Disable problematic services on bootc/ostree
systemctl mask grub-boot-success.timer 2>/dev/null || true

## Remove problematic autostart files
rm -f /etc/xdg/autostart/nvidia-settings-user.desktop 2>/dev/null || true

## Create flatpak exports dir (fix rakuos-flatpak-watcher)
mkdir -p /var/lib/flatpak/exports/bin
