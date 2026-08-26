<div align="center">

# RakuOS-Hyprland

> **⚠️ UNOFFICIAL** — This is **not** an official RakuOS product. It is a community-built, opinionated atomic image on top of [RakuOS](https://rakuos.org) base v3, designed for one person's daily driver: gaming, software development, and a Hyprland desktop with a shell you actually pick, not one you're stuck with.

[![Build Status](https://img.shields.io/badge/build-buildah%20%2B%20bootc-blue)]()
[![Base](https://img.shields.io/badge/base-RakuOS%20v3-informational)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

</div>

---

## Table of Contents

- [What This Is](#what-this-is)
- [Architecture](#architecture)
- [Installation](#installation)
- [Secure Boot (MOK Enrollment)](#secure-boot-mok-enrollment)
- [What's in the Core Image](#whats-in-the-core-image)
- [Gaming — First-Boot Overlay](#gaming--first-boot-overlay)
- [Gaming & Hybrid GPU Environment Variables (Lua)](#gaming--hybrid-gpu-environment-variables-lua)
- [Development Environments (Distrobox)](#development-environments-distrobox)
- [Updating & Rollback](#updating--rollback)
- [Overlay Reset (Factory Clean)](#overlay-reset-factory-clean)
- [Building From Source](#building-from-source)
- [FAQ / Troubleshooting](#faq--troubleshooting)
- [License](#license)

---

## What This Is

RakuOS-Hyprland uses a **three-layer architecture** so that gaming packages, development tooling, and the desktop base live in the appropriate layer instead of being bundled into one large image:

| Layer | What lives here | Managed by | Changes without rebuild? |
|---|---|---|---|
| **Core image** | Hyprland, Mesa/Vulkan, container runtime, and filesystem tooling; the NVIDIA variant also adds DKMS drivers and signing | `bootc` / OSTree | No — rebuild + `bootc switch` |
| **Overlay** | Steam, Faugus Launcher, Heroic, Wine/Proton, and performance tools | Factory-seeded package list; installed by RakuOS on first boot; later managed by `rakuos install` / `rakuos remove` | Yes — install or remove without rebuilding the image |
| **Distrobox** | Language toolchains (Rust, Go, Python, etc.) for your own projects | `distrobox`, user-managed | Yes — fully independent of the image |

The result: gaming and dev tooling both feel "native" (nothing to manually install after a fresh boot), but the core image stays lean, update-fast, and instantly rollback-safe — because none of the heavy, frequently-changing stuff is baked immutably into it.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  CORE IMAGE (read-only, bootc/OSTree)                      │
│  Hyprland · Mesa/Vulkan · SDDM · Network/Audio/Bluetooth    │
│  podman/buildah/distrobox and system tooling                 │
│  (system tooling, à la Bluefin)                              │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│  OVERLAY (package list seeded; installed at first boot)      │
│  Steam · Faugus Launcher · Heroic · Wine/Proton              │
│  gamemode/mangohud · gamescope · controller support          │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│  DISTROBOX (user-space, home-isolated)                       │
│  Rust/Loco.rs, Go, Python, PHP, ... — one container per       │
│  language, cache lives outside your home, reset anytime       │
└──────────────────────────────────────────────────────────┘
```

**Why NVIDIA is in the core image and games are not:** the NVIDIA variant builds the DKMS module for the kernel in that image and can sign it with the supplied MOK key. Steam and the other game tools have no such kernel coupling, so this project places them in the overlay.

---

## Installation

### Quick Install (recommended)

```bash
# 1. Install via bootc
sudo bootc switch ghcr.io/tofan79/rakuos-hyprland:latest

# 2. Reboot
sudo reboot
```

### From another custom image

```bash
sudo bootc switch --transport ghcr.io ghcr.io/tofan79/rakuos-hyprland:latest
```

### After installation

```bash
# Update packages managed by the overlay
sudo rakuos update

# Install additional packages into the overlay
sudo rakuos install <package-name>

# Rebuild the overlay while keeping its package list, then reboot
sudo rakuos reset-overlay --soft
sudo reboot
```

**Development environments** are managed via Distrobox — see [Development Environments (Distrobox)](#development-environments-distrobox) for setup instructions.

---

## Secure Boot (MOK Enrollment)

If Secure Boot is enabled, a blue MokManager screen will appear on first boot:

1. Select **"Enroll MOK"**
2. Select **"Continue"**
3. Select **"Yes"**
4. Enter password: **`rakuos`**
5. Select **"Reboot"**

That's it — the signing key is already embedded in the image.

> If Secure Boot is disabled, skip this — the system boots directly. See [RakuOS Secure Boot docs](https://rakuos.org/docs/secure-boot) for details.

---

## What's in the Core Image

### Hyprland Desktop

| Package | Purpose |
|---|---|
| `hyprland` | Wayland compositor — dynamic tiling window manager |
| `cliphist` | Clipboard manager for Wayland |
| `xdg-desktop-portal-hyprland` | XDG portal backend for Hyprland |
| `hyprland-qt-support`, `hyprsysteminfo`, `hyprtoolkit` | Hyprland ecosystem integration & tooling |
| `gpu-screen-recorder` | GPU-accelerated screen recorder |
| `nwg-look`, `matugen` | GTK theming & Material You color generation |
| `sddm-x11` | Display manager |
| `grim`, `slurp`, `tesseract`, `zbar` | Screenshot, region-select, OCR, QR/barcode reading |

### Graphics & GPU (hardware enablement — why it's core, not overlay)

| Package | Purpose |
|---|---|
| `mesa-dri-drivers`, `mesa-vulkan-drivers` | Open-source GPU driver stack |
| `libva-utils`, `vdpauinfo`, `clinfo` | Hardware video decode / OpenCL diagnostics |
| NVIDIA DKMS stack (NVIDIA variant, via `nvidia.sh`) | Proprietary driver, built for the exact kernel in this image; it is signed when MOK build secrets are supplied |

### Container & Dev Tooling (à la Bluefin — system tooling, baked in core)

| Package | Purpose |
|---|---|
| `podman`, `buildah`, `skopeo` | OCI container engine & image tooling |
| `distrobox`, `host-spawn` | Home-isolated dev containers (see [Development Environments](#development-environments-distrobox)) |
| `git`, `lazygit`, `fzf`, `ripgrep`, `fd-find`, `tmux`, `htop` | Everyday CLI tooling |
| `fuse-overlayfs`, `slirp4netns` | Rootless container networking/storage |

### Audio, Network, Filesystem, Fonts, System

<details>
<summary>Full list</summary>

| Category | Packages |
|---|---|
| Audio | `pipewire`, `wireplumber`, `alsa-utils`, `pavucontrol`, GStreamer plugins, `x264`, `x265` |
| Bluetooth | `bluez`, `bluez-tools` |
| Network | `NetworkManager-wifi`, `NetworkManager-bluetooth`, `NetworkManager-openvpn`, `NetworkManager-wwan` |
| Hardware/Power | `switcheroo-control`, `brightnessctl`, `ddcutil`, `power-profiles-daemon`, `fprintd-pam` |
| File Manager | `nautilus`, `gvfs` (+nfs/fuse/smb/mtp), `gnome-disk-utility`, `gnome-calculator` |
| Input Methods | `ibus-mozc`, `ibus-unikey` |
| Theming | `qt5ct`, `qt6ct`, `qt6-qtwayland`, `papirus-icon-theme` |
| Filesystem | `exfatprogs`, `ntfs-3g`, `btrfs-progs`, `cifs-utils`, `dosfstools` |
| Fonts | `jetbrains-mono-fonts`, `google-noto-color-emoji-fonts`, `adobe-source-code-pro-fonts` |
| System | `dbus-tools`, `logrotate`, `gnome-keyring`, `xdg-desktop-portal(-gtk)`, `xdg-user-dirs-gtk` |
| RakuOS | `rakuos-release`, `rakuos-software-qt`, `rakuos-welcome-gtk` |

</details>

> The project does not explicitly list `.i686` packages. Dependencies selected by the package manager can still include compatibility packages when required by Wine or other overlay software.

---

## Gaming — First-Boot Overlay

The build seeds the default gaming `packages.list` but does **not** install the gaming RPMs into the image. On the first installed boot, `rakuos-overlay-sync.service` installs that list into the mounted persistent `/usr` overlay before the display manager starts. The first boot therefore needs network access and may take longer while the game packages are downloaded and installed.

| Package | Purpose |
|---|---|
| `steam`, `steam-devices` | Valve's game platform + controller/Steam Input udev rules |
| `gamemode`, `mangohud`, `goverlay` | Performance tuning, FPS/telemetry overlay, GUI for MangoHud |
| `faugus-launcher`, `heroic-games-launcher` | Game library managers (native, Epic/GOG/Amazon) |
| `wine`, `winetricks`, `protontricks` | Windows compatibility layer & Proton prefix management |
| `vulkan-tools`, `gamescope` | Vulkan diagnostics, micro-compositor for game isolation |
| `xorg-x11-drv-libinput`, `joystick-support`, `jstest-gtk`, `bluez-hid2hci` | Controller & input device support |

After first-boot provisioning, add a package with `sudo rakuos install <package>`. Remove an overlay package with `sudo rakuos remove <package>`; for example, `sudo rakuos remove faugus-launcher`.

> Package-owned configuration is created by RPM at runtime, not copied into the image during the build. `/etc` is outside the `/usr` overlay mount, so a modified RPM configuration file may be retained as an RPM backup when its package is removed.

---

## Gaming & Hybrid GPU Environment Variables (Lua)

This repository does not ship a Hyprland user configuration or environment-variable file. If your installed Hyprland uses Lua configuration, add any required gaming/NVIDIA variables in your own configuration. The following is only an example to adapt to your hardware.

**Recommended variables for NVIDIA/hybrid laptops:**

```lua
-- NVIDIA Core
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")

-- NVIDIA Hybrid GPU (Optimus)
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")

-- Wayland Compatibility
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11,*")

-- Hyprland NVIDIA Fixes
hl.env("WLR_RENDERER", "vulkan")
hl.env("AQ_FORCE_LINEAR_BLIT", "0")

-- Proton/Wine Tuning
hl.env("DXVK_ASYNC", "1")
hl.env("VKD3D_CONFIG", "dxr")
hl.env("WINE_FULLSCREEN_FSR", "1")
```

**Want to override one variable?** Add your own `hl.env("VAR", "value")` line — Lua executes top to bottom, so your line wins.

> AMD/Intel users: skip the NVIDIA blocks, keep the Wayland compatibility vars — they apply to any GPU.

---

## Development Environments (Distrobox)

Language toolchains (Rust, Go, Bun, Python, PHP, ...) are **never** baked into the image — they change too often and would bloat/stale the image for languages you may not even use. Instead, each one lives in its own home-isolated Distrobox container, created on demand.

```bash
# One-time: create the helper script
mkdir -p ~/RuangCoding
cat > ~/RuangCoding/new-devbox.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
LANG_NAME="${1:?Usage: new-devbox.sh <language> [image]}"
IMAGE="${2:-fedora:latest}"
BOX_HOME="$HOME/RuangCoding/${LANG_NAME}-env"
mkdir -p "$BOX_HOME"
distrobox create --name "coding-${LANG_NAME}" --image "$IMAGE" --home "$BOX_HOME"
echo "✅ Ready. Enter: distrobox enter coding-${LANG_NAME}"
EOF
chmod +x ~/RuangCoding/new-devbox.sh

# Create a Rust environment
~/RuangCoding/new-devbox.sh rust
distrobox enter coding-rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install loco-cli

# Reset completely, any time
distrobox rm coding-rust && rm -rf ~/RuangCoding/rust-env
```

Nothing here touches the core image or the overlay — cache, toolchain versions, and build artifacts stay entirely inside `~/RuangCoding/<language>-env/`.

---

## Updating & Rollback

RakuOS has separate commands for overlay packages and the bootc image:

```bash
# Update packages tracked by the overlay
sudo rakuos update

# Stage the newest bootc image, then reboot to use it
sudo rakuos system-upgrade
sudo reboot

# Return to the previous bootc deployment
sudo bootc rollback
sudo reboot
```

The core image is updated atomically by bootc. NVIDIA driver and kernel changes are delivered together by the NVIDIA image variant.

---

## Overlay Reset (Factory Clean)

Unlike a traditional distro — where years of installs/uninstalls leave orphaned dependencies, stray config files, and bloated package caches that are genuinely hard to fully clean — RakuOS gives you two distinct reset operations, each with a very different effect. **Know which one you're running before you run it.**

| | `rakuos reset-overlay --soft` | Full / "pristine" reset (`--confirm`) |
|---|---|---|
| **What it does** | Rebuilds the overlay **from your own current `packages.list`** | Wipes the overlay and restores the **pristine default** shipped in the image |
| **Packages you installed with `rakuos install`** (e.g. `vlc`) | ✅ Survive — reinstalled automatically | ❌ Lost — not part of the image's default list |
| **Default gaming stack** (Steam, Faugus Launcher, etc.) | ✅ Survive | ✅ Survive (they're part of *this* image's default `packages.list`) |
| **When to use** | Overlay out of sync after an update (e.g. packages show "available but not installed") | You genuinely want to discard everything you've added and start clean |

```bash
# Recovery / sync repair — keeps everything you've installed
sudo rakuos reset-overlay --soft

# Full pristine reset — DISCARDS anything not in this image's default
# packages.list. Confirm you actually want this before running it.
# Full pristine reset — schedules the reset for the next boot.
sudo rakuos reset-overlay --confirm
sudo reboot
```

> **⚠️ The persistent overlay system is still marked experimental by the RakuOS project itself.** Exact command behavior may change between versions — run `rakuos reset-overlay --help` to confirm what your installed version actually does before relying on it, especially before a full reset.

---

## Building From Source

```bash
# Clone repository
git clone https://github.com/tofan79/RakuOs-Hyprland.git
cd RakuOs-Hyprland

# Build with NVIDIA (for NVIDIA/hybrid GPU laptops)
sudo buildah build \
  --file Containerfile.nvidia \
  --build-arg RAKUOS_STAGING=rolling \
  --secret id=mok_key,src=/path/to/MOK.key \
  --secret id=mok_cert,src=/path/to/MOK.der \
  -t rakuos-hyprland:local \
  .

# Build WITHOUT NVIDIA (for AMD-only or Intel GPU desktops/laptops)
sudo buildah build \
  --file Containerfile \
  --build-arg RAKUOS_STAGING=rolling \
  -t rakuos-hyprland:local \
  .

# Test image
podman run -it rakuos-hyprland:local /bin/bash
```

> **Without NVIDIA:** No DKMS, no MOK signing, no secrets needed. Pure Hyprland + Mesa/Vulkan. AMD and Intel GPUs work out of the box.

### CPU Architecture — `rakuos-base-v3`

This image uses `rakuos-base-v3` which targets **x86-64-v3** (AVX2 instruction set). Check your CPU:

| Base Image | CPU Architecture | Instruction Set | Examples |
|---|---|---|---|
| `rakuos-base` | x86-64 (baseline) | SSE2 | Intel Core 2, AMD Bulldozer |
| `rakuos-base-v3` | x86-64-v3 (AVX2) | AVX2+ | **Intel Core i-4xxx+, AMD Ryzen** ← this image |
| `rakuos-base-v4` | x86-64-v4 (AVX-512) | AVX-512+ | Intel Xeon Scalable, AMD EPYC |

**To change CPU target:** edit `BASE_IMAGE_REPO` in both `Containerfile` and `Containerfile.nvidia`:

```dockerfile
# For x86-64 (older CPUs):
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base"

# For x86-64-v4 (server/EPYC):
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-v4"
```

Check your CPU level:
```bash
# If this prints "Y", your CPU supports x86-64-v3 (AVX2)
grep -o avx2 /proc/cpuinfo | head -1
```

> **Note:** the ISO workflow builds an ISO from the published GHCR image for the current date. Build and publish the updated image first; changing a Containerfile alone does not alter an existing ISO.

---

## FAQ / Troubleshooting

**Q: Why isn't Steam showing up right after first boot?**

A: It is installed automatically during first-boot overlay provisioning (see [Gaming](#gaming--first-boot-overlay)). Wait until provisioning completes, then check `rakuos list` and file an issue if it is still missing.

**Q: I edited `~/.config/hypr/hyprland.lua` and it broke on reload — what now?**

A: Hyprland ships emergency keybinds for exactly this: `SUPER+Q` (terminal), `SUPER+R` (run), `SUPER+M` (exit) still work even if your config has a fatal error above them.

**Q: My NVIDIA hybrid GPU laptop isn't offloading correctly.**

A: Confirm you've added the NVIDIA/hybrid GPU variables to your own ~/.config/hypr/hyprland.lua — this image doesn't ship them for you (see [Gaming & Hybrid GPU Environment Variables](#gaming--hybrid-gpu-environment-variables-lua)). Run hyprctl systeminfo after adding them to confirm Hyprland picked up the change.

**Q: Secure Boot asks for a MOK password on first boot — what do I enter?**

A: Enter `rakuos`. The signing key is already embedded in the image — no USB or file needed.

**Q: Can I install `.i686` packages for an old 32-bit-only app?**

A: No — Fedora 44 doesn't build i686 packages at all anymore, in any repo. Check if the app has a Flatpak or an AppImage instead; those bundle their own dependencies.

**Q: I don't have an NVIDIA GPU. Can I still use this image?**

A: Yes — use `Containerfile` (not `Containerfile.nvidia`) when building. No DKMS, no MOK signing needed. AMD and Intel GPUs work out of the box with Mesa/Vulkan.

**Q: I installed something with `rakuos install`, then ran an overlay reset, and now it's gone — what happened?**

A: You ran a full/pristine reset, not a soft one — see [Overlay Reset](#overlay-reset-factory-clean). Pristine reset intentionally discards anything not in this image's default `packages.list`. If you just wanted to fix a sync issue, `rakuos reset-overlay --soft` is what you want next time — it rebuilds from your own package list instead of discarding.

**Q: How do I update the image after a new release?**

A: Run `sudo rakuos system-upgrade`, then reboot. `sudo rakuos update` updates overlay packages only. If the new image causes a problem, `sudo bootc rollback` reverts to the previous deployment.

**Q: How do I reset all overlay packages back to clean state?**

A: The overlay can be wiped entirely — see [Overlay Reset (Factory Clean)](#overlay-reset-factory-clean). Everything in `packages.list` gets reinstalled on next boot.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

**Disclaimer:** This is an unofficial community project and is not affiliated with, endorsed by, or connected to the RakuOS project in any way. RakuOS is a trademark of its respective owners.
