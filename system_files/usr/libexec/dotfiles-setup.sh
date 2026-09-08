#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once (mirrors the official
# RakuOS niri mechanism). The rakuos-installer creates users WITHOUT a full
# skeleton, so without this, Hyprland's modular config (hyprland.lua ->
# require("config.*")) never lands in the home and Hyprland falls back to its
# auto-generated default config.

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

touch "$FIRSTRUN"