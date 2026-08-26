<div align="center">

# RakuOS-Hyprland

> **UNOFFICIAL** — This is **not** an official RakuOS product. It is a community-built, opinionated atomic image on top of [RakuOS](https://rakuos.org) base v3 (NVIDIA), designed as a daily driver for gaming and Hyprland desktop.

[![Build Status](https://img.shields.io/badge/build-buildah%20%2B%20bootc-blue)]()
[![Base](https://img.shields.io/badge/base-RakuOS%20v3%20NVIDIA-informational)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

</div>

---

## Table of Contents

- [What This Is](#what-this-is)
- [Architecture](#architecture)
- [Installation](#installation)
- [What's in the Core Image](#whats-in-the-core-image)
- [Gaming — First-Boot Overlay](#gaming--first-boot-overlay)
- [NVIDIA Environment Variables](#nvidia-environment-variables)
- [Development Environments (Distrobox)](#development-environments-distrobox)
- [Updating & Rollback](#updating--rollback)
- [Building From Source](#building-from-source)
- [FAQ / Troubleshooting](#faq--troubleshooting)
- [License](#license)

---

## What This Is

RakuOS-Hyprland uses a **three-layer architecture** so that gaming packages, development tooling, and the desktop base live in the appropriate layer:

| Layer | What lives here | Managed by | Changes without rebuild? |
|---|---|---|---|
| **Core image** | Hyprland, Mesa/Vulkan, NVIDIA drivers, SDDM, system tooling | `bootc` / OSTree | No — rebuild + `bootc switch` |
| **Overlay** | Steam, Gamemode, MangoHud, Wine/Proton, controller support | Factory-seeded package list; installed at first boot | Yes — `rakuos install` / `rakuos remove` |
| **Distrobox** | Language toolchains (Rust, Go, Python, etc.) | `distrobox`, user-managed | Yes — fully independent |

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  CORE IMAGE (read-only, bootc/OSTree)                      │
│  Hyprland · Mesa/Vulkan · NVIDIA · SDDM                    │
│  Audio · Network · Bluetooth · System tweaks                │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│  OVERLAY (package list seeded; installed at first boot)      │
│  Steam · Gamemode · MangoHud · Heroic · Faugus              │
│  Wine/Proton · Gamescope · Controller support                │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│  DISTROBOX (user-space, home-isolated)                       │
│  Rust, Go, Python, PHP, ... — one container per language     │
└──────────────────────────────────────────────────────────┘
```

---

## Installation

### From GHCR (recommended)

```bash
# Install via bootc
sudo bootc switch ghcr.io/tofan79/rakuos-hyperland:staging

# Reboot
sudo reboot
```

### After installation

```bash
# Update overlay packages
sudo rakuos update

# Install additional packages
sudo rakuos install <package-name>

# Rebuild overlay (keeps your package list)
sudo rakuos reset-overlay --soft
sudo reboot
```

### First Boot

- **Gaming packages** are installed automatically during first boot (overlay system)
- **Hardware groups** (video/render/input) are added to the first user automatically
- First boot needs network access and may take a few minutes

---

## What's in the Core Image

### Hyprland Desktop

| Package | Purpose |
|---|---|
| `hyprland` | Wayland compositor — dynamic tiling window manager |
| `cliphist` | Clipboard manager for Wayland |
| `xdg-desktop-portal-hyprland` | XDG portal backend for Hyprland |
| `hyprland-qt-support`, `hyprsysteminfo`, `hyprtoolkit` | Hyprland ecosystem integration |
| `gpu-screen-recorder` | GPU-accelerated screen recorder |
| `nwg-look`, `matugen` | GTK theming & Material You color generation |
| `sddm-x11` | Display manager |
| `grim`, `slurp`, `tesseract`, `zbar` | Screenshot, region-select, OCR, QR/barcode reading |

### Graphics & GPU

| Package | Purpose |
|---|---|
| `mesa-dri-drivers`, `mesa-vulkan-drivers` | Open-source GPU driver stack |
| `libva-utils`, `vdpauinfo`, `clinfo` | Hardware video decode / OpenCL diagnostics |
| NVIDIA drivers (via base image `rakuos-base-nvidia-v3`) | Proprietary NVIDIA driver stack |

### Audio, Network, System

<details>
<summary>Full list</summary>

| Category | Packages |
|---|---|
| Audio | `pipewire`, `wireplumber`, `alsa-utils`, `pavucontrol`, GStreamer plugins, `x264`, `x265` |
| Bluetooth | `bluez`, `bluez-tools` |
| Network | `NetworkManager-wifi`, `NetworkManager-bluetooth`, `NetworkManager-openvpn`, `NetworkManager-wwan` |
| Hardware/Power | `switcheroo-control`, `brightnessctl`, `ddcutil`, `power-profiles-daemon`, `fprintd-pam` |
| File Manager | `hyprfm`, `gvfs` (+nfs/fuse/smb/mtp), `gnome-disk-utility`, `gnome-calculator` |
| Input Methods | `ibus-mozc`, `ibus-unikey` |
| Theming | `qt5ct`, `qt6ct`, `qt6-qtwayland`, `papirus-icon-theme` |
| Filesystem | `exfatprogs`, `ntfs-3g`, `btrfs-progs`, `cifs-utils`, `dosfstools` |
| Fonts | `jetbrains-mono-fonts`, `google-noto-color-emoji-fonts` |
| System | `dbus-tools`, `logrotate`, `gnome-keyring`, `xdg-desktop-portal(-gtk)`, `xdg-user-dirs-gtk` |
| System tweaks | `vm.max_map_count=2147483642` (Proton gaming), `user.max_user_namespaces=28633` (rootless containers) |

</details>

---

## Gaming — First-Boot Overlay

The build seeds the gaming `packages.list` but does **not** install the gaming RPMs into the image. On first boot, `rakuos-overlay-sync.service` installs that list into the mounted persistent `/usr` overlay.

| Package | Purpose |
|---|---|
| `steam`, `steam-devices` | Valve's game platform + controller/Steam Input udev rules |
| `gamemode`, `mangohud`, `goverlay` | Performance tuning, FPS/telemetry overlay, GUI for MangoHud |
| `faugus-launcher`, `heroic-games-launcher` | Game library managers (native, Epic/GOG/Amazon) |
| `wine`, `winetricks`, `protontricks` | Windows compatibility layer & Proton prefix management |
| `vulkan-tools`, `gamescope` | Vulkan diagnostics, micro-compositor for game isolation |
| `xorg-x11-drv-libinput`, `joystick-support`, `jstest-gtk`, `bluez-hid2hci` | Controller & input device support |

After first boot, add/remove packages with:
```bash
sudo rakuos install <package>
sudo rakuos remove <package>
```

---

## NVIDIA Environment Variables

Add these to your `~/.config/hypr/hyprland.conf` for NVIDIA/hybrid GPU:

```conf
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = NVD_BACKEND,direct
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = MOZ_ENABLE_WAYLAND,1
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11,*
env = WLR_RENDERER,vulkan
env = AQ_FORCE_LINEAR_BLIT,0
env = DXVK_ASYNC,1
env = VKD3D_CONFIG,dxr
env = WINE_FULLSCREEN_FSR,1
```

> AMD/Intel users: skip the NVIDIA blocks, keep the Wayland compatibility vars.

---

## Development Environments (Distrobox)

Install distrobox after first boot:
```bash
sudo rakuos setup-distrobox
```

Then create isolated dev environments:
```bash
# Create a Rust environment
distrobox create --name coding-rust --image fedora:latest
distrobox enter coding-rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Reset completely, any time
distrobox rm coding-rust
```

---

## Updating & Rollback

```bash
# Update overlay packages
sudo rakuos update

# Stage the newest bootc image, then reboot
sudo rakuos system-upgrade
sudo reboot

# Return to the previous bootc deployment
sudo bootc rollback
sudo reboot
```

---

## Building From Source

```bash
# Clone repository
git clone https://github.com/tofan79/rakuos-hyperland.git
cd rakuos-hyperland

# Build (NVIDIA base, staging)
sudo buildah build \
  --file Containerfile \
  --build-arg BASE_IMAGE_TAG=staging \
  --build-arg RAKUOS_STAGING=1 \
  -t rakuos-hyprland:local \
  .

# Test image
podman run -it rakuos-hyprland:local /bin/bash
```

### CPU Architecture

This image uses `rakuos-base-nvidia-v3` which targets **x86-64-v3** (AVX2).

| Base Image | Architecture | Examples |
|---|---|---|
| `rakuos-base` | x86-64 (baseline) | Intel Core 2, AMD Bulldozer |
| `rakuos-base-v3` | x86-64-v3 (AVX2) | **Intel Core i-4xxx+, AMD Ryzen** ← this image |
| `rakuos-base-v4` | x86-64-v4 (AVX-512) | Intel Xeon Scalable, AMD EPYC |

Check your CPU:
```bash
grep -o avx2 /proc/cpuinfo | head -1
```

---

## FAQ / Troubleshooting

**Q: Steam isn't showing up after first boot?**

A: Wait for first-boot overlay provisioning to complete. It needs network access. Check `rakuos list` afterwards.

**Q: My NVIDIA hybrid GPU isn't offloading correctly?**

A: Add the NVIDIA environment variables to your `~/.config/hypr/hyprland.conf` (see [NVIDIA Environment Variables](#nvidia-environment-variables)). Run `hyprctl systeminfo` to verify.

**Q: Can I install `.i686` packages?**

A: No — Fedora 44 doesn't build i686 packages. Use Flatpak or AppImage instead.

**Q: How do I update the image?**

A: `sudo rakuos system-upgrade` then reboot. `sudo rakuos update` only updates overlay packages.

**Q: How do I reset the overlay?**

A: `sudo rakuos reset-overlay --soft` (keeps your packages) or `sudo rakuos reset-overlay --confirm` (factory reset).

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

**Disclaimer:** This is an unofficial community project and is not affiliated with, endorsed by, or connected to the RakuOS project in any way. RakuOS is a trademark of its respective owners.
