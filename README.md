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
- **Keyring/auth**: gnome-keyring intentionally **excluded** (Noctalia/Hyprland
  work fine without `org.freedesktop.secrets` and it caused dual-daemon crashes
  at login with the greetd PAM setup), fprintd-pam, libsecret client lib
- **Base duties**: NetworkManager suite, tuned-ppd, gvfs(+mtp/nfs/smb),
  systemd-oomd-defaults, noctalia-greeter
- **Tools**: swash, tesseract (+10 langpacks), zbar, hyprpicker, cliphist,
  brightnessctl, playerctl, unzip/zip/7zip/unar, bat, fzf, zoxide
- **Theme/fonts**: adw-gtk3-theme, papirus-icon-theme, jetbrains-mono-nerd-fonts
- **Terra** (Vendor repo, enabled at build: `bibata-cursor-theme`,
  `jetbrainsmono-nerd-fonts`, plus base deps `dysk`/`fresh`/`surge`/`termflix`/`wlctl`)
- **Browser (overlay)**: `zen-browser` — prebaked via `packages.list` /
  `packages-live.list`, present on live and installed systems
- **NVIDIA dGPU**: inherited from the Nvidia base image (driver + CUDA stack)
- **Time sync**: `chrony` for automatic NTP (RTC stays UTC — Windows already
  configured with `RealTimeIsUniversal=1`, so no local-time offset)
- **AppArmor (MAC)**: base already boots the kernel with
  `security=apparmor apparmor=1 selinux=0`
  ([kargs.d/10-rakuos.toml](https://gitlab.com/rakuos/rakuos-settings)) — this
  image adds the userspace stack (`apparmor-parser`, `apparmor-profiles`,
  `apparmor-utils`, `apparmor.d-rakuos` profile set). `apparmor.service` is
  installed **disabled**: RakuOS "Full Apparmor support" is still In Progress on
  the project board, so the service stays off until official profiles are
  ready and safe to enforce

### Not included (optional)

Apps below are **not baked** — install them after first boot with:
```bash
sudo rum install <package>     # overlay (survives image upgrades)
sudo dnf5 install <package>    # base image layer (dev-only, not atomic)
```
Hyprland keybinds (`variables.lua`) already point at them:

- **editor** `zeditor`, **calculator** `gnome-calculator`, **video/audio
  player** `mpv`
- **asusctl** (ASUS ROG fan/light control) — install on ASUS hardware only:
  ```bash
  sudo rum install asusctl
  ```

### Overlay & live split

- `packages.list` (overlay — live ISO **and** installed system): `zen-browser`
- `packages-live.list` (live ISO only, not carried into installs): `zen-browser`

## How it's built

`.github/workflows/build.yml` runs on GitHub Actions:

1. `docker buildx build --provenance=false` (single-manifest, so Quay shows
   the real image size)
2. Base = RakuOS `rakuos-base-nvidia-v3:staging` (COPR Hyprland +
   `mindset/Mindset-Apps`, Terra/RPM-Fusion repos tuned)
3. Bakes canonical system GIDs into `/etc/group` (audio/video/input/kvm/utmp
   etc. — the `bootc-minimal` base lacks the `altfiles` NSS module, so
   `getent` falls back to the file) and masks noisy systemd tmpfiles
   (`sudo-message`, `openvpn`, `mdadm`, `dbus` ones) in `build.sh`/`post-build*.sh`
4. Pushes `latest` + date tag to `quay.io/mindset404/hyprland-nvidia-v3`
5. **Retention**: deletes date tags older than the 5 newest (keeps storage
   within Quay free tier)
6. Terra signing-key auto-recovery (refreshes `key.asc` from Fyralabs,
   falls back to disabling `gpgcheck` if the keys rotate again)
7. Enables NTP (`chrony`) and installs/activates the **AppArmor** userspace
   (profiles from `apparmor.d-rakuos`) — SELinux stays removed per base policy

> **Security note:** RakuOS's [project board](https://rakuos.org/project-board)
> tracks "Full Apparmor support" as **in progress**. The base already sets the
> AppArmor kernel LSM; this image pre-adds the official userland packages ahead
> of base shipping them. If the base later bundles these itself, `build.sh`'s
> AppArmor block must be re-checked/synced to avoid double installs.

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

# Later updates are pulled by the 3-day auto-rebuild, or manually:
sudo bootc upgrade
sudo reboot
```

New image tags are pushed to `quay.io/mindset404/hyprland-nvidia-v3:latest`;
pulling that reference is all `bootc upgrade` needs to detect a new build.
The `rakuos-updater.service`+`.timer` (daily at 03:00 UTC) also checks for
new image and overlay updates automatically.

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
   (daemon hangs in D-state); a `fwupdmgr --version` shim keeps firmware API
   consumers non-errored, but LVFS refresh/update is intentionally
   non-functional here.

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