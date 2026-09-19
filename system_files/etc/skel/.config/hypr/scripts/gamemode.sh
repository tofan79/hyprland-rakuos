#!/usr/bin/env bash
# gamemode.sh — toggle/strip Hyprland "gamer mode" decorative effects.
#
# ON  : strips all compositing effects for maximum FPS (animations off,
#       no rounding, no blur, no shadows, opaque windows, zero gaps).
# OFF : restores your EXACT previous look. The first time gamer mode is
#       enabled, every option this script touches is read via
#       `hyprctl getoption` and stored in a cache file, so disabling hands
#       the desktop back your own style (theme rounding, blur passes, etc.),
#       not a hardcoded Hyprland default.
#
# Usage:
#   gamemode.sh            → toggle ON/OFF
#   gamemode.sh on         → force ON  (strip decorations)
#   gamemode.sh off        → force OFF (restore)
#
# Bind it e.g. Super+Shift+B in binds.lua:
#   hl.bind("SUPER SHIFT", "B", "exec", "~/.config/hypr/scripts/gamemode.sh")
#
# nvidiarun --game calls `gamemode.sh on` / `gamemode.sh off` around the game
# so stripping and restoring happen automatically without extra clicks.
#
# Mirrors the boost on/off logic of the Noctalia gamer-mode plugin.

set -euo pipefail

cache_file="$HOME/.cache/gamemode_decor"
declare -A decor

# --- helper: read current value of a hyprctl option, whatever its type ---
# Returns the raw value (e.g. "true", "12", "0.9", "5 5 5 5"); falls back to
# $2 if the option cannot be read. Some options print "set: false" when they
# inherit from a default, but the value line is still present.
read_opt() {
    local option="$1" default="$2"
    local out
    out="$(hyprctl getoption "$option" 2>/dev/null | grep -vE "set:" | head -1)" || true
    out="${out#*: }"                       # strip "css gap data: " / "bool: " / "int: " / "float: "
    out="${out#css gap data: }"
    printf '%s' "${out:-$default}"
}

# First number of a "top right bottom left" CSS gap string.
gap_first() {
    local gap="${1:-0}"
    set -- $gap
    printf '%s' "$1"
}

# --- build the hl.config eval string ---
# Enabling (restoring) uses the snapshot values; disabling is the fixed
# maximum-FPS form. Copied verbatim from service.luau buildBoostOn/Off.
build_on() {
    printf 'hl.config({ animations = { enabled = true }, decoration = { rounding = %s, active_opacity = %s, inactive_opacity = %s, fullscreen_opacity = %s, blur = { enabled = true }, shadow = { enabled = true } }, general = { gaps_in = %s, gaps_out = %s, border_size = %s } })' \
        "${decor[rounding]}" "${decor[active_opacity]}" "${decor[inactive_opacity]}" "${decor[fullscreen_opacity]}" \
        "${decor[gaps_in]}" "${decor[gaps_out]}" "${decor[border_size]}"
}

build_off() {
    printf 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, active_opacity = 1.0, inactive_opacity = 0.9, fullscreen_opacity = 1.0, blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })'
}

# --- snapshot current style if not cached, then strip ---
on() {
    if [ ! -f "$cache_file" ]; then
        declare -A decor=(
            [rounding]="$(read_opt decoration:rounding 12)"
            [active_opacity]="$(read_opt decoration:active_opacity 0.9)"
            [inactive_opacity]="$(read_opt decoration:inactive_opacity 0.7)"
            [fullscreen_opacity]="$(read_opt decoration:fullscreen_opacity 1.0)"
            [gaps_in]="$(gap_first "$(read_opt general:gaps_in '5 5 5 5')")"
            [gaps_out]="$(gap_first "$(read_opt general:gaps_out '10 10 10 10')")"
            [border_size]="$(read_opt general:border_size 2)"
        )
        {
            printf 'decor[rounding]=%q\n' "${decor[rounding]}"
            printf 'decor[active_opacity]=%q\n' "${decor[active_opacity]}"
            printf 'decor[inactive_opacity]=%q\n' "${decor[inactive_opacity]}"
            printf 'decor[fullscreen_opacity]=%q\n' "${decor[fullscreen_opacity]}"
            printf 'decor[gaps_in]=%q\n' "${decor[gaps_in]}"
            printf 'decor[gaps_out]=%q\n' "${decor[gaps_out]}"
            printf 'decor[border_size]=%q\n' "${decor[border_size]}"
        } > "$cache_file"
    fi

    hyprctl eval "$(build_off)"
    notify-send -a gamer-mode "Gamer Mode: ON" "Compositing stripped for max FPS."
}

# --- restore from snapshot if cached ---
off() {
    if [ -f "$cache_file" ]; then
        # shellcheck disable=SC1090
        . "$cache_file"
        hyprctl eval "$(build_on)"
        rm "$cache_file"
        notify-send -a gamer-mode "Gamer Mode: OFF" "Decorations restored."
    fi
}

case "${1:-}" in
    on)  on ;;
    off) off ;;
    "")  if [ -f "$cache_file" ]; then off; else on; fi ;;
    *)   echo "usage: gamemode.sh [on|off]" >&2; exit 2 ;;
esac