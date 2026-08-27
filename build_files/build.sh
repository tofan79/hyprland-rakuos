#!/bin/bash

set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS Hyprland Staging".
RAKUOS_RELEASE_PKG="rakuos-release-niri"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-niri-staging"
fi

## Enable COPR repos
echo "Enabling COPR repos..."
dnf5 -y copr enable lionheartp/Hyprland 2>/dev/null || echo "Warning: Failed to enable Hyprland COPR"
dnf5 -y copr enable mindset/Mindset-Apps 2>/dev/null || echo "Warning: Failed to enable Mindset-Apps COPR"

## Set COPR repo priority to 20 (only touch files with "copr" in name)
for repo_file in /etc/yum.repos.d/*copr*; do
    if [[ -f "$repo_file" ]] && grep -q "copr" "$repo_file"; then
        if grep -q "^priority=" "$repo_file"; then
            sed -i 's/^priority=.*/priority=20/' "$repo_file"
        else
            echo "priority=20" >> "$repo_file"
        fi
        echo "Set priority=20: $(basename "$repo_file")"
    fi
done

## Clear stale repo cache to avoid checksum mismatches
dnf5 clean all

## Install packages — Pure Hyprland edition
rum install -y \
  hyprland cliphist xdg-desktop-portal-hyprland \
  hyprland-qt-support hyprland-guiutils \
  hyprsysteminfo hyprtoolkit gpu-screen-recorder nwg-look matugen \
  sddm-x11 \
  grim slurp tesseract tesseract-langpack-eng tesseract-langpack-ind tesseract-langpack-jpn tesseract-langpack-chi-sim zbar \
  switcheroo-control \
  brightnessctl ddcutil power-profiles-daemon \
  playerctl alsa-utils pavucontrol \
  gstreamer1-plugins-base gstreamer1-plugins-good \
  gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free \
  x264 x265 \
  qt5ct qt6ct qt6-qtwayland papirus-icon-theme \
  exfatprogs ntfs-3g btrfs-progs cifs-utils dosfstools \
  jetbrains-mono-fonts google-noto-color-emoji-fonts \
  dbus-tools logrotate gnome-keyring \
  NetworkManager-wifi NetworkManager-bluetooth NetworkManager-openvpn NetworkManager-config-connectivity-fedora NetworkManager-wwan \
  bluez bluez-tools \
  pipewire wireplumber gvfs-nfs gvfs-fuse gvfs-smb gvfs gvfs-mtp gnome-disk-utility gnome-calculator fprintd-pam ibus-mozc ibus-unikey \
  xorg-x11-server-Xwayland \
  ${RAKUOS_RELEASE_PKG} rakuos-software-qt rakuos-welcome-qt \
  systemd-oomd-defaults xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs-gtk

## Hardware enablement — graphics stack for gaming (kernel/driver-adjacent).
## No .i686 packages are explicitly requested here; dependencies may still
## select compatibility packages when required by an installed application.
rum install -y \
  mesa-dri-drivers mesa-vulkan-drivers libva-utils vdpauinfo clinfo

## Remove unnecessary packages
dnf5 remove -y wofi hyprpicker grimblast || true

## Remove fedora wallpapers
rm -r /usr/share/backgrounds/fedora-workstation/

## Unlock keyring on login
sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/sddm

## Enable Services
systemctl enable sddm
systemctl enable rakuos-firstboot-hwgroups.service
systemctl enable --global dotfiles-setup
