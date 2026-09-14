#!/usr/bin/env bash
# Screenshot tool: auto-saves to ~/Pictures/Screenshots then opens Swash.
# Saving inside Swash overwrites the same shot (Windows Snipping Tool-like).
# The screen is frozen (hyprpicker) while selecting so the selector never
# appears in the capture.
# Dependencies: grim, slurp, hyprctl, hyprpicker, swash, jq, notify-send
set -euo pipefail

app="Screenshot"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
shot="$dir/ss-$(date +%Y%m%d-%H%M%S).png"

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }
for c in grim slurp hyprctl hyprpicker swash jq notify-send; do need "$c"; done

mode="${1:-region}"
freeze_pid=""

freeze() {
  hyprpicker -r -z >/dev/null 2>&1 &
  freeze_pid=$!
  sleep 0.15
}

unfreeze() {
  [[ -n "$freeze_pid" ]] && kill "$freeze_pid" 2>/dev/null || true
}

case "$mode" in
  region|r)
    freeze
    geometry="$(slurp 2>/dev/null)" || { unfreeze; exit 130; }
    unfreeze
    [[ -n "$geometry" ]] || exit 0
    grim -g "$geometry" "$shot"
    ;;
  fullscreen|fs|all)
    grim "$shot"
    ;;
  window|w)
    freeze
    geometry="$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -r 2>/dev/null)" || { unfreeze; exit 130; }
    unfreeze
    [[ -n "$geometry" ]] || exit 0
    grim -g "$geometry" "$shot"
    ;;
  *)
    notify-send -u critical "$app" "Usage: screenshot [region|fullscreen|window]"
    exit 1
    ;;
esac

if [[ ! -s "$shot" ]]; then
  notify-send -u critical "$app" "Capture failed or produced an empty image"
  exit 1
fi

SWASH_SAVE_DIR="$dir" swash "$shot"