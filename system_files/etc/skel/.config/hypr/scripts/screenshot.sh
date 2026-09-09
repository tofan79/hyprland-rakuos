#!/usr/bin/env bash
# Screenshot tool with 3 modes: region, fullscreen, window
# Opens in Satty for annotation before saving
# Dependencies: grim, slurp, hyprctl, hyprpicker, satty, jq, wl-copy, notify-send
set -euo pipefail

app="Screenshot"
tmp="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/screenshot.XXXXXX.png")"
trap 'rm -f "$tmp"' EXIT

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }
for c in grim slurp hyprctl hyprpicker satty jq wl-copy notify-send; do need "$c"; done

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
    grim -g "$geometry" "$tmp"
    ;;
  fullscreen|fs|all)
    grim "$tmp"
    ;;
  window|w)
    freeze
    geometry="$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -r 2>/dev/null)" || { unfreeze; exit 130; }
    unfreeze
    [[ -n "$geometry" ]] || exit 0
    grim -g "$geometry" "$tmp"
    ;;
  *)
    notify-send -u critical "$app" "Usage: screenshot [region|fullscreen|window]"
    exit 1
    ;;
esac

if [[ -s "$tmp" ]]; then
  wl-copy --type image/png < "$tmp"
  # hand a copy to satty so our EXIT trap can clean up the working tmp safely
  copy="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/screenshot-satty.XXXXXX.png")"
  cp "$tmp" "$copy"
  nohup satty --filename "$copy" --save-after-copy >/dev/null 2>&1 &
  disown
else
  notify-send -u critical "$app" "Screenshot failed or produced an empty file"
  exit 1
fi
