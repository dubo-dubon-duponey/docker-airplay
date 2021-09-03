#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Ensure the tmp folder is writable
[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

helpers::dbus(){
  # On container restart, cleanup the crap
  rm -f /run/dbus/pid

  # https://linux.die.net/man/1/dbus-daemon-1
  dbus-daemon --system

  until [ -e /run/dbus/system_bus_socket ]; do
    sleep 1s
  done
}

if [ "${AIRPLAY_VERSION:-}" == 2 ]; then
  # https://superuser.com/questions/1157370/how-to-configure-pulseaudio-to-input-output-via-alsa
  mkdir -p /tmp/pulse-config/.config/pulse
  printf "load-module module-suspend-on-idle\nload-module module-alsa-sink device=$DEVICE\nload-module module-alsa-source device=$DEVICE\nload-module module-native-protocol-unix\n" > /tmp/pulse-config/.config/pulse/default.pa

  # Pulse will create the socket in /tmp/pulse/native
  export XDG_RUNTIME_DIR=/tmp/pulse-socket
  mkdir -p "$XDG_RUNTIME_DIR"
  mkdir -p /tmp/pulse-config
  helpers::dbus
  HOME=/tmp/pulse-config pulseaudio --start > /dev/stdout 2>&1
  # LANG=C pulseaudio -vvvv --log-time=1 > ~/pulseverbose.log 2>&1
  # XXX
  sleep 5
  cd /tmp
  export PULSE_SERVER="$XDG_RUNTIME_DIR"/pulse/native
  exec goplay2 -n "$MDNS_NAME" "$@"

# XXX allow debugging with PULSE_SERVER=/tmp/pulse-socket/pulse/native HOME=/tmp/pulse-config pactl info
fi

args=(--port "$PORT" --output "$OUTPUT" --name "$MDNS_NAME" --use-stderr --mdns tinysvcmdns --configfile /config/shairport-sync/main.conf)

LOG_LEVEL="$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')"
[ "$LOG_LEVEL" != "debug" ] || args+=(-vvv --statistics)

exec shairport-sync "${args[@]}" "$@"
