# RakuOS Hyprland Image

Custom **Hyprland** spin of [RakuOS](https://rakuos.org) — a hybrid atomic,
immutable Linux distro built on Fedora. This repository builds an OCI image
with Hyprland + uWSM, the Noctalia greeter, and a tuned toolchain for laptops
with **NVIDIA dGPU + AMD iGPU** (e.g. ASUS ROG).

## Image

| Key            | Value                                              |
| -------------- | -------------------------------------------------- |
| Registry       | `quay.io/mindset404/hyprland-atomic`               |
| Base image     | `quay.io/rakuos/rakuos-base-nvidia-v3:staging`     |
| Architecture   | `linux/amd64`                                      |
| Tags           | `latest`, `<YYYYMMDD>` (date tag, **5 kept**)      |
| Rebuild        | **Every 3 days** (`cron: 0 17 */3 * *`, 17:00 UTC) |

### Included

- **Desktop**: Hyprland, uWSM, noctalia (greeter), kitty, neovim
- **Portal/multimedia**: xdg-desktop-portal(-hyprland/-gtk), pipewire,
  wireplumber, egl-wayland, wl-clipboard, grim+slurp, pavucontrol
- **Keyring/auth**: gnome-keyring, fprintd-pam, ibus-mozc
- **Base duties**: NetworkManager suite, power-profiles-daemon, gvfs(+mtp/nfs),
  systemd-oomd-defaults, rakuos-software, rakuos-welcome, noctalia-greeter
- **NVIDIA dGPU**: inherited from the Nvidia base image (driver + CUDA stack)

### Not included (optional)

- **asusctl** (ASUS ROG fan/light control): now in `packages.list` — install on
  ASUS hardware only:
  ```bash
  sudo rum install asusctl
  ```

## How it's built

`.github/workflows/build.yml` runs on GitHub Actions:

1. `docker buildx build --provenance=false` (single-manifest, so Quay shows
   the real image size)
2. Base = RakuOS `rakuos-base-nvidia-v3:staging` (COPR Hyprland +
   `mindset/Mindset-Apps`, Terra/RPM-Fusion repos tuned)
3. Pushes `latest` + date tag to `quay.io/mindset404/hyprland-atomic`
4. **Retention**: deletes date tags older than the 5 newest (keeps storage
   within Quay free tier)
5. Terra signing-key auto-recovery (refreshes `key.asc` from Fyralabs,
   falls back to disabling `gpgcheck` if the keys rotate again)

### Manual trigger

```bash
gh workflow run "Build RakuOS Hyprland Image" --repo tofan79/hyprland-rakuos
```

Workflow inputs: `base_image_tag` (default `staging`) and `rakuos_staging`
(default `1`).

## Install / switch to this build

```bash
# From the live ISO or another image
sudo bootc switch quay.io/mindset404/hyprland-atomic:latest
sudo reboot

# Later updates are pulled automatically by RakuOS Software Center / bootc
sudo bootc upgrade
```

The RakuOS software center detects updates via the Quay API (`specificTag=latest`)
— this image is a full Quay reference, so update badges work out of the box.

## Live ISO

The bootable ISO (greetd/noctalia, livesys handling, NVIDIA initramfs) is built
locally with **rakuos-forge** from the separate repo:
[`tofan79/rakuos-hyprland-iso`](https://github.com/tofan79/rakuos-hyprland-iso)
(`sudo ./build-local.sh`).

## License

Licensed under the [Apache License 2.0](LICENSE).

This project builds on **[RakuOS](https://rakuos.org)** — atomic image-based
Linux on Fedora. RakuOS projects are Apache 2.0 as well
(see [gitlab.com/rakuos](https://gitlab.com/rakuos), e.g. `rakuos-base`).
Hyprland is GPL-3.0; uWSM, Noctalia and included packages retain their own
licenses.

> **Disclaimer:** This is an **unofficial, community-built image**. It is not
> affiliated with, endorsed by, or a product of the RakuOS project. "RakuOS"
> and associated marks are property of their respective owners and are used
> only to describe the upstream base this image builds on.