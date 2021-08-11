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
  helpers::dbus
  HOME=/tmp pulseaudio --start
  cd /tmp
  exec goplay2 -n "$MDNS_NAME" "$@"
fi

args=(--port "$PORT" --output "$OUTPUT" --name "$MDNS_NAME" --use-stderr --mdns tinysvcmdns --configfile /config/shairport-sync/main.conf)

LOG_LEVEL="$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')"
[ "$LOG_LEVEL" != "debug" ] || args+=(-vvv --statistics)

exec shairport-sync "${args[@]}" "$@"
