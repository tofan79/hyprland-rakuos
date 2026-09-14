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

# Re-enable Terra: rakuos-base now ships post-build.sh with terra disabled by
# default (rum config-manager --set-disabled terra). This image installs
# terra-hosted packages (bibata-cursor-theme, jetbrainsmono-nerd-fonts, plus
# base deps like dysk/fresh/surge/termflix/wlctl), so enable it explicitly.
# --set-enabled also flips enabled_metadata=1.
rum config-manager --set-enabled terra 2>/dev/null || true
sed -i '/^\[terra\]$/,/^\[/ s/^\(enabled\|enabled_metadata\)=0/\1=1/' /etc/yum.repos.d/terra.repo 2>/dev/null || true

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
  ghostty \
  ghostty-shell-integration \
  ghostty-terminfo \
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
  eza \
  fastfetch \
  starship \
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
  unar \
  bat \
  fzf \
  zoxide

## Populate skeleton wallpaper folder with the OFFICIAL base RakuOS wallpaper
## set. Noctalia's wallpaper picker points at ~/Pictures/Wallpaper so users get
## a real selection out of the box (and can drop in their own files anytime).
mkdir -p /etc/skel/Pictures/Wallpaper
for wpdir in /usr/share/wallpapers/RakuOS-*/; do
    wpimg=$(find "$wpdir" -path '*/contents/images/*.png' | head -n1)
    if [ -n "$wpimg" ]; then
        cp -n "$wpimg" "/etc/skel/Pictures/Wallpaper/$(basename "$wpdir").png"
    fi
done
cp -n /usr/share/wallpapers/default.jpg /etc/skel/Pictures/Wallpaper/default.jpg || true

## Set Bibata as default cursor theme systemwide
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF

## Remove wofi
rum remove -y wofi 2>/dev/null || true

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

## Harden sudoers drop-in for the RakuOS Updates plugin (0440 root:root)
chmod 0440 /etc/sudoers.d/rakuos-plugin-updates 2>/dev/null || true

## Ensure state dir ownership (fallback if setup script didn't run)
if [ -d /var/lib/noctalia-greeter ]; then
    mkdir -p /var/lib/noctalia-greeter/.themes
    chown -R greeter:greeter /var/lib/noctalia-greeter
    chmod 0750 /var/lib/noctalia-greeter
fi

## Enable NTP: chrony keeps clock synced across reboots.
## RTC is UTC (Windows already configured with RealTimeIsUniversal=1 in registry),
## so no need for timedatectl set-local-rtc — both OS agree on UTC.
rum install -y chrony
systemctl enable chronyd

## Install AppArmor userspace tools (MAC replacement for SELinux)
##
## The RakuOS base ALREADY ships kernel LSM config in
## /usr/lib/bootc/kargs.d/10-rakuos.toml:
##     kargs = ["security=apparmor", "apparmor=1", "selinux=0"]
## so the kernel boots with AppArmor active (check /sys/kernel/security/lsm).
## What's missing here is only userspace: the parser, profiles, tools, and the
## RakuOS profile set.
##
## SAFETY: "Full Apparmor support" is still In Progress on the RakuOS project
## board, and several DE services (greetd, noctalia-greeter, uwsm, hyprland,
## pipewire) may not have complete enforced profiles yet. So we install the
## tools ONLY and keep apparmor.service DISABLED — the service stays off until
## the official profile set is released. Enforcing now risks login/audio
## breakage that is hard to roll back.
##
## NOTE: If the base image later ships these packages natively, review/sync
## this block so we don't double-install or conflict with the official
## packaging.
rum install -y \
  apparmor-parser \
  apparmor-profiles \
  apparmor-utils \
  apparmor.d-rakuos

## apparmor-parser ships system presets (70-apparmor.preset -> enable), so
## explicitly disable the service: tools are staged but not activated.
systemctl disable apparmor.service 2>/dev/null || true

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

## Quiet cosmetic systemd-tmpfiles noise on immutable systems:
## - home.conf: /home and /srv are symlinks into /var here, so the Q/q rules
##   log "/home already exists and is not a directory" every boot.
## - root.conf: its `z / 555` rule tries to chmod /, which is a read-only
##   composefs mount -> "fchmod() of / failed: Read-only file system".
## - provision.conf: instead of masking it entirely, ship a trimmed copy that
##   keeps the (credential-based) provisioning behavior but drops the `d- /root`
##   line, which hits the /root -> /var/roothome symlink and logs "/root already
##   exists and is not a directory" every boot.
mkdir -p /etc/tmpfiles.d
ln -sfn /dev/null /etc/tmpfiles.d/home.conf
ln -sfn /dev/null /etc/tmpfiles.d/root.conf
cat > /etc/tmpfiles.d/provision.conf << 'EOF'
# Trimmed copy of /usr/lib/tmpfiles.d/provision.conf:
# the `d- /root` line is dropped because /root is a symlink to /var/roothome
# on this immutable system (would log "already exists and is not a directory").

# Provision additional login messages from credentials, if they are set. Note
# that these lines are NOPs if the credentials are not set or if the files
# already exist.
f^ /etc/motd.d/50-provision.conf - - - - login.motd
f^ /etc/issue.d/50-provision.conf - - - - login.issue

# Provision a /etc/hosts file from credentials.
f^ /etc/hosts - - - - network.hosts

# Provision SSH key for root
d- /root/.ssh :0700 root :root -
f^ /root/.ssh/authorized_keys :0600 root :root - ssh.authorized_keys.root
EOF


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
