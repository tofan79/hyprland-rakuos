# RakuOS Hyprland — Security Setup Guide

## Cosign (Container Image Signing)

### 1. Generate key pair (local)

```bash
cosign generate-key-pair
```

This creates:
- `cosign.key` (private key — keep secret!)
- `cosign.pub` (public key — share with others)

### 2. Store in GitHub Secrets

```bash
# Encode private key to base64
base64 -w0 cosign.key

# Copy the output and add to GitHub Secrets:
# Go to: https://github.com/tofan79/RakuOs-Hyprland/settings/secrets/actions
# New repository secret:
#   Name: COSIGN_KEY
#   Value: <base64 encoded key>
```

```bash
# Set password for the key (you created this during key generation)
# Go to: https://github.com/tofan79/RakuOs-Hyprland/settings/secrets/actions
# New repository secret:
#   Name: COSIGN_PASSWORD
#   Value: <your password>
```

### 3. Add public key to repo

```bash
cp cosign.pub ./rakuos-hyprland.pub
git add rakuos-hyprland.pub
git commit -m "Add cosign public key for image verification"
git push
```

### 4. Verify signed image

```bash
cosign verify \
  --key https://raw.githubusercontent.com/tofan79/hyprland-rakuos/main/rakuos-hyprland.pub \
  ghcr.io/tofan79/hyprland-rakuos:latest
```

---

## MOK (Secure Boot — Machine Owner Key)

### 1. Generate MOK key pair

```bash
# Generate private key + DER certificate (what CI needs)
openssl req -new -x509 \
  -newkey rsa:2048 \
  -keyout MOK.key \
  -outform DER \
  -out MOK.der \
  -nodes \
  -days 36500 \
  -subj "/CN=RakuOS Hyprland Module Signing Key/"
```

This creates:
- `MOK.key` (private key — store in GitHub Secrets)
- `MOK.der` (DER certificate — store in GitHub Secrets)

### 2. Store in GitHub Secrets

```bash
# Encode private key to base64
base64 -w0 MOK.key

# Add to GitHub Secrets:
#   Name: MOK_KEY
#   Value: <base64 encoded MOK.key>
```

```bash
# Encode DER certificate to base64
base64 -w0 MOK.der

# Add to GitHub Secrets:
#   Name: MOK_CERT
#   Value: <base64 encoded MOK.der>
```

### 3. Enroll MOK in UEFI

On first boot, the MokManager screen appears automatically:

1. Select **"Enroll MOK"**
2. Select **"Continue"**
3. Select **"Yes"**
4. Enter password: **`rakuos`**
5. Select **"Reboot"**

No USB drive needed — the signing key is already embedded in the image via `sb_pubkey.der`.

### 4. Verify enrollment

```bash
mokutil --list-enrolled | grep "RakuOS Hyprland"
```

---

## How it works

### Build time:
```
GitHub Actions
  → cosign sign (container image)
  → nvidia.sh: sign-file (kernel modules) with MOK.key
  → nvidia.sh: sbsign (vmlinuz) with MOK.key
  → post-build.sh: replace sb_pubkey.der with MOK.der
```

### Boot time:
```
UEFI Secure Boot
  → MokManager appears (first boot only)
  → User enrolls our key with password "rakuos"
  → verify vmlinuz (signed by MOK)
  → verify nvidia.ko (signed by MOK)
  → boot system
```

### User verification:
```
podman pull ghcr.io/tofan79/hyprland-rakuos:latest
cosign verify --key https://raw.githubusercontent.com/tofan79/RakuOs-Hyprland/main/rakuos-hyprland.pub ghcr.io/tofan79/hyprland-rakuos:latest
```
