#!/usr/bin/env bash
# Emit a Noctalia-coloured dossier header line for fastfetch.
# Reads the rendered palette (themes/noctalia.jsonc) so the accent square,
# dash rules and section labels follow the active Noctalia scheme instead of
# being hard-coded. Fallbacks: Noctalia vermillion accent, warm off-white title.
set -u
theme="${HOME}/.config/fastfetch/themes/noctalia.jsonc"

acc_hex="226;52;42"      # fallback: Noctalia vermillion
title_hex="243;237;225"  # fallback: warm off-white
muted_hex="143;135;112"  # fallback: muted taupe

if [ -f "$theme" ]; then
  keys="$(jq -r '.display.color.keys // empty' "$theme" 2>/dev/null)"
  title="$(jq -r '.display.color.title // empty' "$theme" 2>/dev/null)"
  if [[ "$keys" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    hex="${keys#\#}"
    acc_hex="$((16#${hex:0:2}));$((16#${hex:2:2}));$((16#${hex:4:2}))"
  fi
  if [[ "$title" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    hex="${title#\#}"
    title_hex="$((16#${hex:0:2}));$((16#${hex:2:2}));$((16#${hex:4:2}))"
  fi
fi

label="${1:-}"
case "$label" in
  "brand")
    # ■ RAKUOS · 楽 · a hybrid atomic desktop
    printf '\033[38;2;%sm■\033[0m \033[38;2;%smRAKUOS · 楽 · a hybrid atomic desktop\033[0m\n' "$acc_hex" "$muted_hex"
    ;;
  *)
    # ── LABEL ────────────── (label + trailing dashes stay the original style)
    printf '\033[38;2;%sm──\033[0m \033[1;38;2;243;237;225m%s\033[0m \033[38;2;58;46;36m─────────────────────────\033[0m\n' "$acc_hex" "$label"
    ;;
esac