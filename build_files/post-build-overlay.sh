#!/usr/bin/env bash
# post-build-overlay.sh
# Runs inside the container build (Containerfile RUN step / GitHub Actions).
#
# Does NOT install packages — that's impossible inside a container build
# because overlayfs on /usr requires CAP_SYS_ADMIN and a real kernel mount.
#
# Instead, this script seeds /usr/share/factory/var/lib/rakuos/ so the first
# deployed system gets a populated /var/lib/rakuos/ state:
#   - packages.list populated from /usr/share/rakuos/packages.list
#   - overlay upper/work dirs created and empty
#   - overlay.state intentionally absent
#
# On first boot, rakuos-overlay-sync.service sees the missing state file,
# treats it as a fresh/reset system, and performs a full install into the
# overlay automatically — no user interaction needed.
#
# Usage (from your Containerfile):
#   RUN /usr/libexec/rakuos/build/post-build-overlay.sh

set -euo pipefail

DEFAULT_PACKAGES_LIST="/usr/share/rakuos/packages.list"
FACTORY_VAR_ROOT="/usr/share/factory/var"
PACKAGES_LIST="$FACTORY_VAR_ROOT/lib/rakuos/packages.list"
UPPER_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/upper"
WORK_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/work"
STATE_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.state"
DIRTY_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.dirty"
FACTORY_RUM_RPMDB="$FACTORY_VAR_ROOT/lib/rakuos/rum-rpmdb"

echo "[rakuos] Seeding overlay state for first-boot install..."

prebake_overlay_from_installroot() {
    local installroot
    local -a prebake_packages=()

    mapfile -t prebake_packages < <(
        grep -v '^\s*#' "$PACKAGES_LIST" \
        | grep -v '^\s*$' \
        | sed 's/\s*#.*//' \
        | tr -s ' \t' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
    )

    if [[ ${#prebake_packages[@]} -eq 0 ]]; then
        echo "[rakuos] No overlay packages listed; skipping prebake."
        return 0
    fi

    installroot="$(mktemp -d /var/tmp/rakuos-overlay-installroot.XXXXXX)"
    trap 'rm -rf "$installroot"' RETURN

    echo "[rakuos] Prebaking overlay packages into installroot via rum..."
    rum install --installroot "$installroot" --setopt=tsflags=noscripts -y --refresh "${prebake_packages[@]}"

    rm -f "$installroot/usr/share/icons/default/index.theme"

    echo "[rakuos] Copying prebaked /usr payload into overlay upper..."
    rm -rf "$UPPER_DIR" "$WORK_DIR"
    mkdir -p "$UPPER_DIR" "$WORK_DIR"
    cp -a "$installroot/usr/." "$UPPER_DIR/"

    echo "[rakuos] Copying prebaked rum overlay rpmdb into factory seed..."
    rm -rf "$FACTORY_RUM_RPMDB"
    mkdir -p "$(dirname "$FACTORY_RUM_RPMDB")"
    cp -a "$installroot/var/lib/rakuos/rum-rpmdb" "$FACTORY_RUM_RPMDB"

    # Skip /etc copy — gaming packages (wine, steam) pull samba-winbind which
    # creates wbpriv group (GID 964) and tmpfiles.d entries that fail bootc lint.
    # These packages are installed at runtime via overlay, so /etc is handled then.

    echo "prebaked-installroot" > "$STATE_FILE"
    rm -f "$DIRTY_FILE"

    echo "[rakuos] Overlay prebake complete."
}

# ── Create runtime dirs ───────────────────────────────────────────────────────

mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR"
mkdir -p "$WORK_DIR"

# ── Seed packages.list ────────────────────────────────────────────────────────

if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    PKG_COUNT=$(grep -v '^\s*#' "$PACKAGES_LIST" | grep -v '^\s*$' | wc -l)
    echo "[rakuos] packages.list seeded with $PKG_COUNT packages."
else
    echo "[rakuos] WARNING: No default packages.list at $DEFAULT_PACKAGES_LIST"
    echo "[rakuos] Creating empty packages.list — no packages will be installed on first boot."
    touch "$PACKAGES_LIST"
fi

# ── Ensure stale state is cleared before prebake writes fresh state ───────────
rm -f "$STATE_FILE" "$DIRTY_FILE"

# Ensure packages.list ends with newline
sed -i -e '$a\' "$PACKAGES_LIST"

echo "[rakuos] stale overlay state cleared — prebake will write fresh first-boot state."
echo "[rakuos] Post-build seed complete."

echo "Appending hyprland protected packages to protected-packages.txt..."
cat >> /usr/share/rakuos/protected-packages.txt << 'EOF'

# Hyprland packages (from rakuos-hyprland/build_files/build.sh)
  hyprland
  cliphist
  xdg-desktop-portal-hyprland
  hyprland-qt-support
  hyprland-guiutils
  hyprsysteminfo
  hyprtoolkit
  gpu-screen-recorder
  nwg-look
  matugen
  sddm-x11
  grim
  slurp
  tesseract
  tesseract-langpack-eng
  tesseract-langpack-ind
  tesseract-langpack-jpn
  tesseract-langpack-chi-sim
  zbar
  switcheroo-control
  brightnessctl
  ddcutil
  power-profiles-daemon
  playerctl
  alsa-utils
  pavucontrol
  gstreamer1-plugins-base
  gstreamer1-plugins-good
  gstreamer1-plugins-bad-free
  gstreamer1-plugins-ugly-free
  x264
  x265
  qt5ct
  qt6ct
  qt6-qtwayland
  papirus-icon-theme
  exfatprogs
  ntfs-3g
  btrfs-progs
  cifs-utils
  dosfstools
  jetbrains-mono-fonts
  google-noto-color-emoji-fonts
  dbus-tools
  logrotate
  gnome-keyring
  NetworkManager-wifi
  NetworkManager-bluetooth
  NetworkManager-openvpn
  NetworkManager-config-connectivity-fedora
  NetworkManager-wwan
  bluez
  bluez-tools
  pipewire
  wireplumber
  gvfs-nfs
  gvfs-fuse
  gvfs-smb
  gvfs
  gvfs-mtp
  gnome-disk-utility
  gnome-calculator
  fprintd-pam
  ibus-mozc
  ibus-unikey
  xorg-x11-server-Xwayland
  rakuos-release-niri
  rakuos-software-qt
  rakuos-welcome-qt
  systemd-oomd-defaults
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-user-dirs-gtk
  mesa-dri-drivers
  mesa-vulkan-drivers
  libva-utils
  vdpauinfo
  clinfo

EOF
rum remove -y 'selinux-policy*' 'policycoreutils-gui'
rum install -y libselinux

# selinux-policy is fully removed on RakuOS (AppArmor is the sole MAC), but the
# baked-in rpm-ostree treefile still defaults "selinux": true. rpm-ostree reads
# that flag on every deploy-time layering operation and tries to load a policy
# from / that no longer exists, causing spurious sepolicy-mismatch failures.
if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json
fi

echo "Generating base file manifest..."
/usr/libexec/rakuos/generate-base-manifest

# Gaming packages (wine, steam) have RPM scriptlets needing /bin/sh
ln -sf /usr/bin/bash /bin/sh || true

echo "Prebaking hyprland overlay payload..."
prebake_overlay_from_installroot
