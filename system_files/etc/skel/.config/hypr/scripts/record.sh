#!/usr/bin/env bash
# Screen recorder tool with 3 modes: region, fullscreen, window
# Run again while recording to stop (toggle). Add --audio to record system audio.
# Dependencies: wf-recorder, slurp, hyprctl, hyprpicker, jq, notify-send
set -euo pipefail

app="Recorder"
outdir="$HOME/Videos/Recordings"
mkdir -p "$outdir"
pidfile="/tmp/wf-recorder.pid"
filefile="/tmp/wf-recorder.file"
logfile="/tmp/wf-recorder.log"

need() { command -v "$1" >/dev/null 2>&1 || { notify-send -u critical "$app" "$1 is not installed"; exit 1; }; }
for c in wf-recorder slurp hyprctl hyprpicker jq notify-send; do need "$c"; done

# Toggle: if already recording, stop it
if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  kill -INT "$(cat "$pidfile")"
  # wait briefly for wf-recorder to finalize the mp4 cleanly
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$(cat "$pidfile")" 2>/dev/null || break
    sleep 0.3
  done
  rm -f "$pidfile"
  saved="$(cat "$filefile" 2>/dev/null || echo "unknown")"
  rm -f "$filefile"
  notify-send "$app" "Recording stopped. Saved to $saved"
  exit 0
fi

mode="region"
audio=""
for arg in "$@"; do
  case "$arg" in
    --audio) audio="--audio" ;;
    region|r|fullscreen|fs|all|window|w) mode="$arg" ;;
    *) notify-send -u critical "$app" "Usage: record [region|fullscreen|window] [--audio]"; exit 1 ;;
  esac
done

freeze_pid=""
freeze() {
  hyprpicker -r -z >/dev/null 2>&1 &
  freeze_pid=$!
  sleep 0.15
}
unfreeze() {
  [[ -n "$freeze_pid" ]] && kill "$freeze_pid" 2>/dev/null || true
}

file="$outdir/recording-$(date +%Y%m%d-%H%M%S).mp4"

case "$mode" in
  region|r)
    freeze
    geometry="$(slurp 2>/dev/null)" || { unfreeze; exit 130; }
    unfreeze
    [[ -n "$geometry" ]] || exit 0
    # shellcheck disable=SC2086
    wf-recorder -g "$geometry" $audio -f "$file" >"$logfile" 2>&1 &
    ;;
  fullscreen|fs|all)
    # shellcheck disable=SC2086
    wf-recorder $audio -f "$file" >"$logfile" 2>&1 &
    ;;
  window|w)
    freeze
    geometry="$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp -r 2>/dev/null)" || { unfreeze; exit 130; }
    unfreeze
    [[ -n "$geometry" ]] || exit 0
    # shellcheck disable=SC2086
    wf-recorder -g "$geometry" $audio -f "$file" >"$logfile" 2>&1 &
    ;;
esac

pid=$!
disown

# verify it actually started instead of dying immediately (missing codec, bad geometry, etc.)
sleep 0.4
if ! kill -0 "$pid" 2>/dev/null; then
  err="$(tail -n 3 "$logfile" 2>/dev/null || echo "unknown error")"
  notify-send -u critical "$app" "Failed to start: $err"
  exit 1
fi

echo "$pid" > "$pidfile"
echo "$file" > "$filefile"
notify-send "$app" "Recording started ($mode). Run the same command again to stop."
