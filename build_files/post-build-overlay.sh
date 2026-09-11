#!/usr/bin/env bash
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
    rum install --installroot "$installroot" -y --refresh --setopt=tsflags=noscripts "${prebake_packages[@]}"

    rm -f "$installroot/usr/share/icons/default/index.theme"

    echo "[rakuos] Copying prebaked /usr payload into overlay upper..."
    rm -rf "$UPPER_DIR" "$WORK_DIR"
    mkdir -p "$UPPER_DIR" "$WORK_DIR"
    cp -a "$installroot/usr/." "$UPPER_DIR/"

    echo "[rakuos] Copying prebaked rum overlay rpmdb into factory seed..."
    rm -rf "$FACTORY_RUM_RPMDB"
    mkdir -p "$(dirname "$FACTORY_RUM_RPMDB")"
    cp -a "$installroot/var/lib/rakuos/rum-rpmdb" "$FACTORY_RUM_RPMDB"

    if [[ -d "$installroot/etc" ]] && [[ -n "$(ls -A "$installroot/etc" 2>/dev/null)" ]]; then
        echo "[rakuos] Copying prebaked /etc payload into image..."
        cp -a "$installroot/etc/." /etc/
    fi

    echo "prebaked-installroot" > "$STATE_FILE"
    rm -f "$DIRTY_FILE"

    echo "[rakuos] Overlay prebake complete."
}

mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR"
mkdir -p "$WORK_DIR"

if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    mapfile -t _seeded < <(grep -v '^\s*#' "$PACKAGES_LIST" | grep -v '^\s*$')
PKG_COUNT="${#_seeded[@]}"
    echo "[rakuos] packages.list seeded with $PKG_COUNT packages."
else
    touch "$PACKAGES_LIST"
    echo "[rakuos] WARNING: No default packages.list - creating empty list."
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
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber
xdg-desktop-portal
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
xorg-x11-server-Xwayland
wl-clipboard
egl-wayland
grim
slurp
wtype
fprintd-pam
adw-gtk3-theme
papirus-icon-theme
bibata-cursor-theme
jetbrainsmono-nerd-fonts
gvfs
gvfs-mtp
gvfs-nfs
gvfs-smb
pavucontrol
NetworkManager-adsl
NetworkManager-bluetooth
NetworkManager-ppp
NetworkManager-wwan
nm-connection-editor
tuned-ppd
libnotify
noctalia-greeter-git
qt6ct
systemd-oomd-defaults
swash
tesseract
tesseract-langpack-eng
tesseract-langpack-ind
tesseract-langpack-jpn
tesseract-langpack-jpn_vert
tesseract-langpack-kor
tesseract-langpack-kor_vert
tesseract-langpack-chi_sim
tesseract-langpack-chi_sim_vert
tesseract-langpack-chi_tra
tesseract-langpack-chi_tra_vert
zbar
zsh-autosuggestions
zsh-syntax-highlighting
hyprpicker
cliphist
brightnessctl
playerctl
dolphin
nomacs
unzip
zip
7zip
unar
PKGLIST

rum remove -y 'selinux-policy*' 'policycoreutils-gui'
rum install -y libselinux

# selinux-policy is fully removed on RakuOS (AppArmor is the sole MAC), but the
# baked-in rpm-ostree treefile still defaults "selinux": true. rpm-ostree reads
# that flag on every deploy-time layering operation and tries to load a policy
# from / that no longer exists, causing spurious sepolicy-mismatch failures.
if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json
fi

echo "[rakuos] stale overlay state cleared — prebake will write fresh first-boot state."
echo "[rakuos] Post-build seed complete."

echo "Generating base file manifest..."
/usr/libexec/rakuos/generate-base-manifest

echo "Prebaking hyprland overlay payload..."
prebake_overlay_from_installroot
