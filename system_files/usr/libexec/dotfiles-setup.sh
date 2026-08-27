#!/bin/bash

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true

touch "$FIRSTRUN"
