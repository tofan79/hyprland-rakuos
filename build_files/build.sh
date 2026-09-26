#!/bin/bash

set -ouex pipefail

# Enable COPR for KineticWE and its Noctalia shell, plus the Hyprland COPR
# that upstream KineticWE also uses.
dnf -y copr enable mindset/Mindset-Apps
dnf -y copr enable lionheartp/Hyprland

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

# Terra ships disabled by default (third-party repos are opt-in), so enable
# it here in case any packages below come from Terra. It stays enabled for the
# whole build stage — the overlay prebake in post-build-overlay.sh resolves
# packages.list too — and is disabled again at the end of that script.
rum config-manager --set-enabled terra

## Ensure rpm scriptlets can find a /bin/sh interpreter in this baseless OCI image
# Some pulled packages (e.g. tk, kf6-kdoctools) run %prein/%post scriptlets via the
# absolute path /bin/sh; a merged-usr base without /bin fails with
# "failed to exec scriptlet interpreter /bin/sh: No such file or directory".
mkdir -p /bin
ln -sfn /usr/bin/sh /bin/sh
ln -sfn /usr/bin/bash /usr/bin/sh 2>/dev/null || true

## Install packages
## nss-altfiles: base already references the "altfiles" NSS service in
## /etc/nsswitch.conf (passwd/group) and ships /usr/lib/group + /usr/lib/passwd,
## but the module library is absent from the minimal image. Without it, initrd
## tmpfiles/udev cannot resolve system groups (audio, video, disk, tty, utmp,
## ...) and log ~45 "Failed to resolve group" warnings every boot. Installing
## the module completes the chain defined in nsswitch.conf and removes the noise.
rum install -y --refresh \
  nss-altfiles \
  kineticwe-git \
  kitty \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  xorg-x11-server-Xwayland \
  egl-wayland \
  fprintd-pam \
  adw-gtk3-theme \
  colloid-theme \
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
  power-profiles-daemon \
  libnotify \
  sddm \
  sddm-x11 \
  xorg-x11-drv-nvidia-xorg-libs \
  qt6-qtdeclarative \
  qt6-qt5compat \
  qt6-qtsvg \
  qt6ct \
  qt6-qtimageformats \
  systemd-oomd-defaults \
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
  wl-clipboard \
  dolphin \
  nomacs \
  unzip \
  zip \
  7zip \
  unar \
  bat \
  fzf \
  zoxide \
  rakuos-welcome-qt \
  rakuos-system-qt \
  rakuos-software-qt

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

## Remove superseded packages
rum remove -y wofi waybar swaylock alacritty fuzzel 2>/dev/null || true

## Enable NTP: chrony keeps clock synced across reboots.
## RTC is UTC (Windows already configured with RealTimeIsUniversal=1 in registry),
## so no need for timedatectl set-local-rtc — both OS agree on UTC.
rum install -y chrony
systemctl enable chronyd

## Enable Services
systemctl enable sddm
systemctl enable --global dotfiles-setup

## Disable periodic rum metadata refresh:
## rum-makecache.timer runs `rum makecache` 10min after boot and every ~3h on
## AC power. On immutable images packages are baked in at build time, so the
## periodic refresh is wasted network traffic — rum fetches metadata on demand
## during install anyway. Rationale from upstream: keep it disabled on images.
systemctl disable rum-makecache.timer 2>/dev/null || true

## [NVIDIA dGPU pre-baked image] Mask dkms:
## nvidia modules are pre-baked into the image for its exact kernel, so the
## boot-time autoinstall always fails ("already installed, need --force").
## Kernel updates come bundled with freshly compiled modules from the image CI,
## so runtime dkms is never needed.
## ► Devices without an NVIDIA dGPU may skip this block (safe to ignore).
systemctl mask dkms.service 2>/dev/null || true

## Disable grub-boot-success: it also ships a user-scope unit that fires 2min
## after login and fails (grub2-set-bootflag needs root), spamming a failed
## service notification every session. Mask system AND user scope.
systemctl mask grub-boot-success.service grub-boot-success.timer 2>/dev/null || true
mkdir -p /etc/systemd/user
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.service
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.timer

## [This device — AMD+NVIDIA hybrid ASUS laptop] Disable fwupd:
## the daemon hangs in D-state on this hardware, stalling boot ~3min and
## ending in a failed unit. Firmware updates stay manual (menu/EFI).
## ► Other devices: do NOT disable — fwupd works normally on other hardware.
ln -sfn /dev/null /etc/systemd/system/fwupd.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.timer

## Mask mcelog: mcelog userspace daemon does not support AMD (Zen) CPUs and
## aborts at every boot ("mcelog: ERROR: AMD Processor family 23: mcelog does
## not support this processor"), leaving a spurious failed unit. AMD MCE
## decoding is handled in-kernel (edac_mce_amd) already, so this is cosmetic.
## Relevant here: AMD Ryzen 7 4800H (Zen 2, ACPI family 17h reported as 23).
## ► AMD-only device; Intel machines should keep mcelog enabled.
systemctl mask mcelog.service 2>/dev/null || true

## Power management: tuned (a plain tuner from the base image) is left in
## place, but tuned-ppd — the layer that claimed the Power Profiles API — is
## replaced by power-profiles-daemon above. Mask the base's tuned.service +
## tuned-ppd.service so only one power manager owns CPU tuning and the PPD
## D-Bus interface. Without the mask, tuned's default "balanced" profile
## (governor + energy_performance_preference + platform_profile) would fight
## power-profiles-daemon over the same sysfs knobs. tuned.service itself is
## auto-enabled by the tuned package preset at install time, so it must be
## masked here explicitly.
systemctl mask tuned.service tuned-ppd.service 2>/dev/null || true

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

## [NVIDIA dGPU] Remove autostart entries that are noisy/failing at login:
## - nvidia-settings-load: --load-config-only (X11-only) intermittently
## ► AMD-only devices: this file does not exist, rm -f is a no-op (safe).
rm -f /etc/xdg/autostart/nvidia-settings-load.desktop 2>/dev/null || true

## RakuOS Software Center: install engine + Qt frontend, but do NOT autostart
## the tray daemon. The only trigger for it is the XDG autostart file below
## (no systemd unit / dbus activation); removing it keeps the Software Center
## fully functional while skipping the background tray at every login.
rm -f /etc/xdg/autostart/rakuos-software-tray.desktop

## Create flatpak exports dir (fix rakuos-flatpak-watcher)
mkdir -p /var/lib/flatpak/exports/bin
