#!/usr/bin/sh
# Wait for DRM devices to settle before launching the greeter compositor.
# On NVIDIA+AMD hybrid laptops (PRIME), logind needs a few seconds after
# the greeter TTY session is created before TakeDevice(card1) succeeds.
# Without this delay the compositor falls back to the NVIDIA card whose
# connectors are all disconnected, producing a frozen/blank greeter on
# VT1.  The user then has to manually restart greetd from another TTY.
sleep 3
exec /usr/bin/noctalia-greeter-session "$@"
