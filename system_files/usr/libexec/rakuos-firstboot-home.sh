#!/bin/bash
# Populate user homes from /etc/skel (missing files only) on first boot, so the
# Hyprland/Noctalia/kitty configs land in new user homes. The RakuOS installer
# creates the user account without a full skeleton (only ~/.config/hyprland.lua
# ends up in $HOME), which makes Hyprland fall back to its default config.
# Idempotent: runs once per boot install (marker in /var/lib/rakuos).

marker="/var/lib/rakuos/.user-skel-done"
[ -e "$marker" ] && exit 0

getent passwd |
    awk -F: '$3>=1000 && $3<60000 && $7 !~ /nologin|false/ && $6!="" {print $1 ":" $6}' |
    while IFS=: read -r user home; do
        [ -d "$home" ] || continue
        cp -an --no-preserve=ownership /etc/skel/. "$home"/ 2>/dev/null || true
        chown -Rh "$user:$user" "$home" 2>/dev/null || true
        echo "rakuos-firstboot: populated home for $user from /etc/skel" >>/dev/kmsg
    done

mkdir -p /var/lib/rakuos
touch "$marker"