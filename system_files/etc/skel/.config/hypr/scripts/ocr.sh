#!/usr/bin/env bash
# Screenshot region -> OCR text -> clipboard
# Usage: ocr.sh [--file /path/to/image.png] [--lang eng+ind]
# With no --lang, auto-detects by running tesseract against every installed
# language together (eng+ind+jpn+kor+chi_sim+chi_tra) — tesseract itself
# picks the best-matching model per line/word, since it has no true
# single-language content detector.
# Dependencies: grim, slurp, hyprctl, hyprpicker, tesseract, wl-copy, notify-send
set -euo pipefail

app="OCR"
default_langs=(eng ind jpn kor chi_sim chi_tra)
lang=""
input_file=""

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }

# parse args (order-independent)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ -n "${2:-}" ]] || { notify-send -u critical "$app" "Missing image path after --file"; exit 2; }
      input_file="$2"; shift 2
      ;;
    --lang)
      [[ -n "${2:-}" ]] || { notify-send -u critical "$app" "Missing language code after --lang"; exit 2; }
      lang="$2"; shift 2
      ;;
    *)
      notify-send -u critical "$app" "Usage: ocr [--file path] [--lang eng+ind]"
      exit 1
      ;;
  esac
done

for c in tesseract wl-copy notify-send; do need "$c"; done

tmp=""
if [[ -n "$input_file" ]]; then
  [[ -r "$input_file" ]] || { notify-send -u critical "$app" "Cannot read image at $input_file"; exit 1; }
  tmp="$input_file"
else
  for c in grim slurp hyprpicker; do need "$c"; done
  tmp="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/ocr.XXXXXX.png")"
  trap 'rm -f "$tmp"' EXIT

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

installed="$(tesseract --list-langs 2>/dev/null | tail -n +2)"

if [[ -n "$lang" ]]; then
  # explicit --lang: validate every sub-language, fail loudly if any is missing
  IFS='+' read -ra requested <<< "$lang"
  for l in "${requested[@]}"; do
    if ! grep -qx "$l" <<< "$installed"; then
      notify-send -u critical "$app" "Language data for '$l' not installed"
      exit 1
    fi
  done
else
  # auto mode: use whichever of the default set is actually installed
  available=()
  for l in "${default_langs[@]}"; do
    grep -qx "$l" <<< "$installed" && available+=("$l")
  done
  if [[ "${#available[@]}" -eq 0 ]]; then
    notify-send -u critical "$app" "No tesseract language data installed"
    exit 1
  fi
  lang="$(IFS=+; echo "${available[*]}")"
fi

if ! text="$(tesseract "$tmp" - -l "$lang" 2>/tmp/ocr-tesseract.log)"; then
  err="$(tail -n 2 /tmp/ocr-tesseract.log 2>/dev/null || echo "tesseract failed")"
  notify-send -u critical "$app" "OCR failed: $err"
  exit 1
fi

if [[ -z "${text//[[:space:]]/}" ]]; then
  notify-send -u normal "$app" "No text found"
  exit 0
fi

printf '%s' "$text" | wl-copy
notify-send -u low "$app" "Text copied to clipboard"
