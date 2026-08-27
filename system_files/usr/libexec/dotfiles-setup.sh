#!/bin/bash

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

# Set cursor theme for Hyprland (Lua config — uses string assignment syntax)
if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
    sed -i 's/^cursor = .*/cursor = "Adwaita"/' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true
fi

# Ensure scripts are executable
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true

touch "$FIRSTRUN"
