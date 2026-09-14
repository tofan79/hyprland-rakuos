#!/usr/bin/env bash
# Screenshot region -> QR code decode -> clipboard (+ open URL if applicable)
# Dependencies: grim, slurp, hyprctl, hyprpicker, zbarimg, wl-copy, xdg-open, notify-send
set -euo pipefail

app="QR Code"
need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }

input_file=""
if [[ "${1:-}" == "--file" ]]; then
  [[ -n "${2:-}" ]] || { notify-send -u critical "$app" "Missing image path"; exit 2; }
  input_file="$2"; shift 2
fi

for c in zbarimg wl-copy notify-send xdg-open; do need "$c"; done

tmp="$input_file"
if [[ -z "$tmp" ]]; then
  for c in grim slurp hyprpicker; do need "$c"; done
  tmp="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/qr.XXXXXX.png")"
  trap 'rm -f "$tmp"' EXIT
fi

if [[ -n "$input_file" ]]; then
  [[ -r "$tmp" ]] || { notify-send -u critical "$app" "Cannot read image at $tmp"; exit 1; }
else
  freeze_pid=""
  hyprpicker -r -z >/dev/null 2>&1 &
  freeze_pid=$!
  sleep 0.15

  geometry="$(slurp 2>/dev/null)" || { kill "$freeze_pid" 2>/dev/null || true; exit 130; }
  kill "$freeze_pid" 2>/dev/null || true
  [[ -n "$geometry" ]] || exit 0

  grim -g "$geometry" "$tmp"

  if [[ ! -s "$tmp" ]]; then
    notify-send -u critical "$app" "Capture failed or produced an empty image"
    exit 1
  fi
fi

result="$(zbarimg --raw "$tmp" 2>/tmp/qr-zbarimg.log | head -n 1 || true)"
if [[ -z "$result" ]]; then
  notify-send -u normal "$app" "No QR code found"
  exit 0
fi

printf '%s' "$result" | wl-copy

case "$result" in
  http://*|https://*)
    if xdg-open "$result" >/dev/null 2>&1; then
      notify-send -u low "$app" "Opened: $result"
    else
      notify-send -u normal "$app" "Copied to clipboard (couldn't open browser): $result"
    fi
    ;;
  *)
    notify-send -u low "$app" "Copied to clipboard: $result"
    ;;
esac
