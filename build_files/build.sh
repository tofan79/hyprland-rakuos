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

## Terra repo keys refresh
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

## Ensure rpm scriptlets can find a /bin/sh interpreter in this baseless OCI image
# Some pulled packages (e.g. tk, kf6-kdoctools) run %prein/%post scriptlets via the
# absolute path /bin/sh; a merged-usr base without /bin fails with
# "failed to exec scriptlet interpreter /bin/sh: No such file or directory".
mkdir -p /bin
ln -sfn /usr/bin/sh /bin/sh
ln -sfn /usr/bin/bash /usr/bin/sh 2>/dev/null || true

## Install packages
rum install -y --refresh \
  hyprland \
  hyprland-guiutils \
  noctalia-git \
  uwsm \
  kitty \
  kitty-shell-integration \
  kitty-terminfo \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  xorg-x11-server-Xwayland \
  wl-clipboard \
  egl-wayland \
  grim \
  slurp \
  wtype \
  fprintd-pam \
  adw-gtk3-theme \
  papirus-icon-theme \
  bibata-cursor-theme \
  jetbrainsmono-nerd-fonts \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  pavucontrol \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  tuned-ppd \
  libnotify \
  noctalia-greeter-git \
  qt6ct \
  systemd-oomd-defaults \
  swash \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  tesseract \
  tesseract-langpack-eng \
  tesseract-langpack-ind \
  tesseract-langpack-jpn \
  tesseract-langpack-jpn_vert \
  tesseract-langpack-kor \
  tesseract-langpack-kor_vert \
  tesseract-langpack-chi_sim \
  tesseract-langpack-chi_sim_vert \
  tesseract-langpack-chi_tra \
  tesseract-langpack-chi_tra_vert \
  zbar \
  hyprpicker \
  cliphist \
  brightnessctl \
  playerctl \
  dolphin \
  nomacs \
  unzip \
  zip \
  7zip \
  unar

## Set Bibata as default cursor theme systemwide
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF

## Remove wofi
rum remove -y wofi 2>/dev/null || true

## Remove fedora wallpapers
rm -rf /usr/share/backgrounds/fedora-workstation/

## Create required system groups (fixes systemd-tmpfiles warnings)
## plugdev is also created: it is referenced by U2F/ZSA/switch udev rules but
## absent on Fedora, producing repeated "Failed to resolve group 'plugdev'"
## warnings at boot.
for group in audio video input disk tty kvm render lp clock kmem sgx utmp plugdev; do
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

## Make greetd wrapper executable (sourced from system_files/)
chmod +x /usr/libexec/rakuos/rakuos-greetd-wrapper.sh 2>/dev/null || true

## Ensure state dir ownership (fallback if setup script didn't run)
if [ -d /var/lib/noctalia-greeter ]; then
    chown -R greeter:greeter /var/lib/noctalia-greeter
    chmod 0750 /var/lib/noctalia-greeter
fi

## Enable Services
systemctl enable greetd
systemctl enable --global dotfiles-setup

## Mask dkms: nvidia modules are pre-baked into the image for its exact kernel,
## so the boot-time autoinstall always fails ("already installed, need --force").
## Kernel updates come bundled with freshly compiled modules from the image CI,
## so runtime dkms is never needed.
systemctl mask dkms.service 2>/dev/null || true

## Disable grub-boot-success: it also ships a user-scope unit that fires 2min
## after login and fails (grub2-set-bootflag needs root), spamming a failed
## service notification every session. Mask system AND user scope.
systemctl mask grub-boot-success.service grub-boot-success.timer 2>/dev/null || true
mkdir -p /etc/systemd/user
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.service
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.timer

## Disable fwupd: the daemon hangs in D-state on this hardware, stalling boot
## ~3min and ending in a failed unit. Firmware updates stay manual (menu/EFI).
ln -sfn /dev/null /etc/systemd/system/fwupd.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.timer


## Remove autostart entries that are noisy/failing at login:
## - nvidia-settings-load: --load-config-only (X11-only) intermittently
##   exits status=1 on Wayland (race: "Cannot find any crtc or sizes")
## - rakuos-software-tray / rakuos-welcome: emit desktop-file (duplicate
##   Name, empty Path) and portal warnings. Launchable manually from menu.
rm -f /etc/xdg/autostart/nvidia-settings-load.desktop 2>/dev/null || true
rm -f /etc/xdg/autostart/rakuos-software-tray.desktop 2>/dev/null || true
rm -f /etc/xdg/autostart/rakuos-welcome.desktop 2>/dev/null || true

## Create flatpak exports dir (fix rakuos-flatpak-watcher)
mkdir -p /var/lib/flatpak/exports/bin
