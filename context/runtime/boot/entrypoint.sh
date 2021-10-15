#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"

helpers::dir::writable "/tmp"

# Traditional, shairport-sync airplay goes here
if [ "${AIRPLAY_VERSION:-}" != 2 ]; then
  args=(--port "$PORT" --output "$OUTPUT" --name "$MDNS_NAME" --use-stderr --mdns tinysvcmdns --configfile /config/shairport-sync/main.conf)

  [ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "debug" ] || args+=(-vvv --statistics)

  exec shairport-sync "${args[@]}" "$@"
fi

##############################################################################################
# goplay / airplay2 goes here
##############################################################################################
# Right, this just does not work with iOS anymore - plus, sync sucks, plus, pulseaudio is a dumpster fire
# So, use at your own peril
helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "$XDG_STATE_HOME" create
helpers::dir::writable "$XDG_CACHE_HOME" create

helpers::dbus(){
  # On container restart, cleanup the crap
  rm -f /run/dbus/pid

  # https://linux.die.net/man/1/dbus-daemon-1
  dbus-daemon --system

  until [ -e /run/dbus/system_bus_socket ]; do
    sleep 1s
  done
}

# https://superuser.com/questions/1157370/how-to-configure-pulseaudio-to-input-output-via-alsa
helpers::dir::writable "/tmp/pulse-config/.config/pulse" create
printf "load-module module-suspend-on-idle\nload-module module-alsa-sink device=%s\nload-module module-alsa-source device=%s\nload-module module-native-protocol-unix\n" "$DEVICE" "$DEVICE" > /tmp/pulse-config/.config/pulse/default.pa

# Pulse will create the socket in /tmp/pulse/native
export XDG_RUNTIME_DIR=/tmp/pulse-socket
helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "/tmp/pulse-config" create
helpers::dbus
HOME=/tmp/pulse-config XDG_CONFIG_HOME=/tmp/pulse-config pulseaudio --start > /dev/stdout 2>&1
# LANG=C pulseaudio -vvvv --log-time=1 > ~/pulseverbose.log 2>&1
# XXX
sleep 5
cd /tmp
export PULSE_SERVER="$XDG_RUNTIME_DIR"/pulse/native
exec goplay2 -n "$MDNS_NAME" "$@"

# XXX allow debugging with PULSE_SERVER=/tmp/pulse-socket/pulse/native HOME=/tmp/pulse-config pactl info

