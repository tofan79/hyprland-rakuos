#!/usr/bin/env bash
# Screenshot region -> upload to a public host -> Google reverse image search
# NOTE: the captured image is uploaded to a public anonymous host (uguu.se)
# and is reachable by anyone with the URL until that host expires it.
# Don't use this on anything sensitive/private.
# Dependencies: grim, slurp, hyprctl, hyprpicker, curl, jq, xdg-open, notify-send
set -euo pipefail

app="Google Lens"
upload_host="https://uguu.se/upload"

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }

input_file=""
if [[ "${1:-}" == "--file" ]]; then
  [[ -n "${2:-}" ]] || { notify-send -u critical "$app" "Missing image path"; exit 2; }
  input_file="$2"; shift 2
fi

for c in curl jq notify-send xdg-open; do need "$c"; done

tmp="$input_file"
if [[ -z "$tmp" ]]; then
  for c in grim slurp hyprpicker; do need "$c"; done
  tmp="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/google-lens.XXXXXX.png")"
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

notify-send -u low "$app" "Uploading to Google Lens..."

if ! response="$(curl -fsS --connect-timeout 10 --max-time 45 -F "files[]=@${tmp}" "$upload_host")"; then
  notify-send -u critical "$app" "Upload failed (network error or host down)"
  exit 1
fi

remote_url="$(printf '%s' "$response" | jq -r '.files[0].url // .files[0].src // empty' 2>/dev/null || true)"
if [[ -z "$remote_url" ]]; then
  notify-send -u critical "$app" "Upload succeeded but no URL was returned"
  exit 1
fi

encoded_url="$(jq -nr --arg url "$remote_url" '$url|@uri')"

if ! xdg-open "https://www.google.com/searchbyimage?image_url=${encoded_url}" >/dev/null 2>&1; then
  notify-send -u critical "$app" "Uploaded, but couldn't open a browser. URL: $remote_url"
  exit 1
fi

notify-send -u low "$app" "Opened in browser"
