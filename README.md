# RakuOS Hyprland Image

Custom **Hyprland** spin of [RakuOS](https://rakuos.org) — a hybrid atomic,
immutable Linux distro built on Fedora. This repository builds an OCI image
with Hyprland + uWSM, the Noctalia greeter, and a tuned toolchain for laptops
with **NVIDIA dGPU + AMD iGPU** (e.g. ASUS ROG).

## Image

| Key            | Value                                              |
| -------------- | -------------------------------------------------- |
| Registry       | `quay.io/mindset404/hyprland-nvidia-v3`               |
| Base image     | `quay.io/rakuos/rakuos-base-nvidia-v3:staging`     |
| Architecture   | `linux/amd64`                                      |
| Tags           | `latest`, `<YYYYMMDD>` (date tag, **5 kept**)      |
| Rebuild        | **Every 3 days** (`cron: 0 17 */3 * *`, 17:00 UTC) |

### Included

- **Desktop**: Hyprland, uWSM, noctalia (greeter), kitty
- **Portal/media**: xdg-desktop-portal(-hyprland/-gtk), pipewire + ALSA +
  PulseAudio emulation, wireplumber, egl-wayland, Xwayland, wl-clipboard,
  grim+slurp, pavucontrol, libnotify
- **Keyring/auth**: gnome-keyring(+PAM), fprintd-pam
- **Base duties**: NetworkManager suite, tuned-ppd, gvfs(+mtp/nfs/smb),
  systemd-oomd-defaults, rakuos-software, rakuos-welcome, noctalia-greeter
- **Tools**: swash, tesseract (+10 langpacks), zbar, hyprpicker, cliphist,
  brightnessctl, playerctl, unzip/zip/7zip/unar
- **Theme/fonts**: adw-gtk3-theme, papirus-icon-theme, jetbrains-mono-nerd-fonts
- **Browser (overlay)**: `brave-origin` — prebaked via `packages.list` /
  `packages-live.list`, present on live and installed systems
- **NVIDIA dGPU**: inherited from the Nvidia base image (driver + CUDA stack)

### Not included (optional)

Apps below are **not baked** — install them after first boot (e.g. via the
RakuOS welcome setup or Software Center). Hyprland keybinds (`variables.lua`)
already point at them:

- **editor** `zeditor`, **calculator** `gnome-calculator`, **video/audio
  player** `mpv`
- **asusctl** (ASUS ROG fan/light control) — install on ASUS hardware only:
  ```bash
  sudo rum install asusctl
  ```

### Overlay & live split

- `packages.list` (overlay — live ISO **and** installed system): `brave-origin`
- `packages-live.list` (live ISO only, not carried into installs): `brave-origin`

## How it's built

`.github/workflows/build.yml` runs on GitHub Actions:

1. `docker buildx build --provenance=false` (single-manifest, so Quay shows
   the real image size)
2. Base = RakuOS `rakuos-base-nvidia-v3:staging` (COPR Hyprland +
   `mindset/Mindset-Apps`, Terra/RPM-Fusion repos tuned)
3. Pushes `latest` + date tag to `quay.io/mindset404/hyprland-nvidia-v3`
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
sudo bootc switch quay.io/mindset404/hyprland-nvidia-v3:latest
sudo reboot

# Later updates are pulled automatically by RakuOS Software Center / bootc
sudo bootc upgrade
```

The RakuOS software center detects updates via the Quay API (`specificTag=latest`)
— this image is a full Quay reference, so update badges work out of the box.

## Update & troubleshooting

This image follows the RakuOS base on a **floating** tag, so each rebuild pulls
the latest `rakuos-base-nvidia-v3:staging`. Upstream ships 1–3 base updates per
day; our builds run:

- **Automatically every 3 days** at 17:00 UTC (`0 17 */3 * *`)
- **Manually anytime** via `Actions → Run workflow`

### Base digest tracing

Every build records which exact base it was built from:

- Step **"Resolve base image digest"** prints the digest before building.
- The digested value is baked into the image label `org.rakuos.base-digest`.
- The run page shows a **Build info** summary (base digest + commit revision).

Use it to pin down regressions: compare the digest of a failing build against
the last known-good one.

### When to look / what to do

1. **After every update** — quick sanity check:
   ```bash
   sudo bootc upgrade && sudo reboot
   systemctl --failed            # expect empty
   ```
2. **Build fails** → read the failing step. Cause is usually one of:
   - Upstream **base staging change** (often kernel/`dkms-nvidia`/rakuos-core) —
     compare the failed digest with the last successful one, then retry.
   - **Our layer** (prebake/scriptlets, `post-build*.sh`, `system_files`) — fix
     in this repo and rebuild.
3. **Runtime issue after upgrading** → check the digest of the running image
   (`podman image inspect --format '{{.Labels}}' ...`). If it regressed from a
   base change, report upstream (`rakuos-base`); to rebuild against an older
   base, temporarily pin the digest in `Containerfile` and re-trigger.
4. **Known device quirks** (ASUS + NVIDIA dGPU / AMD iGPU): harmless kernel
   "noise" at boot — ACPI `_TZ.THRM._SCP`, `NVRM PlatformRequestHandler`
   SBIOS assertions, `amdgpu DCN reg offset`, and `bpf-restrict-fs` are benign
   and do not affect performance. `fwupd` stays **masked** on this hardware
   (daemon hangs in D-state); a `fwupdmgr --version` shim keeps the software
   center's firmware check non-errored, but LVFS refresh/update is intentionally
   non-functional here.

## Live ISO

The bootable ISO (greetd/noctalia, livesys handling, NVIDIA initramfs) is built
locally with **rakuos-forge** from the separate repo:
[`tofan79/rakuos-hyprland-iso`](https://github.com/tofan79/rakuos-hyprland-iso)
(`sudo ./build-local.sh`).

### Noctalia polkit agent

Noctalia's built-in polkit agent (used by the RakuOS installer and other
privileged GUI apps) ships **off by default**. Enable it once per session:
**Noctalia settings → polkit agent → on** (also required by
`rakuos-installer-qt` — otherwise install fails with
`Error creating textual authentication agent ... '/dev/tty': No such device`).

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