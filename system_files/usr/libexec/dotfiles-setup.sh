#!/bin/bash

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

# Set cursor theme for Hyprland
if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
    sed -i 's/^cursor = .*/cursor = Adwaita/' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true
fi

touch "$FIRSTRUN"
