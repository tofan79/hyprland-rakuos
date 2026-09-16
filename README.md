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

- **Desktop**: Hyprland, uWSM, noctalia (greeter), ghostty
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
- **Apps**: `rakuos-software-qt` (Software Center) + `rakuos-welcome-qt` —
  installed baked, autostart entries removed (open only via menu)
- **Browser (overlay)**: `zen-browser` — prebaked via `packages.list` /
  `packages-live.list`, present on live and installed systems
- **NVIDIA dGPU**: inherited from the Nvidia base image (driver + CUDA stack)
- **Time sync**: `chrony` for automatic NTP (RTC stays UTC — Windows already
  configured with `RealTimeIsUniversal=1`, so no local-time offset)
- **AppArmor (MAC)**: `DEFERRED` — base already boots the kernel with
  `security=apparmor apparmor=1 selinux=0`
  ([kargs.d/10-rakuos.toml](https://gitlab.com/rakuos/rakuos-settings)), and this
  image currently ships **no** AppArmor userspace. RakuOS "Full Apparmor
  support" is still In Progress on the project board; when the official
  packages land in the CI repos, enable them here

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

### Noctalia Updates plugin & sudoers

The Noctalia "Updates" panel plugin shows/installs pending image + overlay
updates from the desktop. It runs headless helpers via sudo, so the repo ships
an extra sudoers drop-in `system_files/etc/sudoers.d/rakuos-plugin-updates`
(chmod `0440 root:root` in `build.sh`) granting **narrow** NOPASSWD to exactly
the commands the plugin runs:

- `rakuos-reset-overlay --soft/--confirm` (overlay cleanup after updates)
- `bootc kargs *`, `flatpak update -y`
- `rum config-manager` / `dnf5 config-manager` repo toggles
- `tee /etc/systemd/zram-generator.conf`

Scope is deliberately narrow (no blanket `ALL`). Without it the plugin would
prompt for a password on every update; on systems that never use the Updates
plugin the drop-in is inert. Filename and format mirror the base's own
`/etc/sudoers.d/rakuos` (sudo-rs).

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

### Known device quirks (ASUS TUF Gaming A15 FA506ICB)

Reference hardware for this image: **ASUS TUF Gaming A15 FA506ICB** —
AMD **Ryzen 7 4800H** (Zen 2) + **Radeon iGPU** (Vega) + **NVIDIA dGPU**
(hooked through the NVIDIA v3 base). Two categories of quirks:

**1. Harmless boot/kernel "noise"** (log-only, no functional impact):
- ACPI `_TZ.THRM._SCP` / `AE_NOT_FOUND` — thermal ACPI method stub
- `NVRM PlatformRequestHandler` SBIOS assertions (get temp / power mode)
- `amdgpu DCN reg offset` — internal display register dump at init
- `bpf-restrict-fs` — BPF LSM object load failure on this kernel
- `mcelog` fails: **AMD CPUs are not supported by the mcelog userspace**
  daemon (`AMD Processor family 23`); AMD MCE decoding is in-kernel
  (`edac_mce_amd`) so the unit is `mask`ed in `build.sh`

**2. Real hardware workarounds shipped in this image**:
- **MT7921 Wi-Fi hang** (`14c3:7961`, MediaTek Filogic 330): driver can hang
  ~minutes after boot with `driver own failed` / `Timeout for driver own` /
  `chip reset failed` (known upstream bugs #215391, #220353). Two drop-ins:
  - `system_files/etc/modprobe.d/mt7921e-aspm.conf` — `disable_aspm=1`,
    an official MediaTek module param that disables PCIe ASPM L1
  - `system_files/etc/NetworkManager/conf.d/wifi-powersave.conf` —
    `wifi.powersave = 2` (disables Wi-Fi power save, same approach Omarchy)
- **fwupd** stays **masked** on this hardware (daemon hangs in D-state); a
  `fwupdmgr --version` shim keeps firmware API consumers non-errored, but
  LVFS refresh/update is intentionally non-functional here.
- **TSC → HPET clocksource fallback**: the clocksource watchdog flags TSC
  `unstable due to frequency skew` vs HPET at boot and falls back to HPET
  (lower timekeeping performance). CPU here has an invariant TSC
  (`constant_tsc` + `nonstop_tsc`), so the TSC is reliable and the HPET is the
  drifting one. Fixed with karg `tsc=reliable`, baked via
  `system_files/usr/lib/bootc/kargs.d/11-hyprland-tsc.toml` (merged by bootc
  over the base's `10-rakuos.toml`, applied on next `bootc upgrade`).

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