#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"

helpers::dir::writable "/tmp"

# Traditional, shairport-sync airplay goes here
if [ "${_EXPERIMENTAL_AIRPLAY_VERSION:-}" != 2 ]; then
  args=(--port "$PORT" --output "$OUTPUT" --name "$MDNS_NAME" --use-stderr --mdns tinysvcmdns --configfile /config/shairport-sync/main.conf)

  [ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "debug" ] || args+=(-vvv --statistics)
  args+=("$@")
  [ ! "$DEVICE" ] || [ "$OUTPUT" != "alsa" ] || args+=(-- -d "$DEVICE")

  exec shairport-sync "${args[@]}"
fi

# Options that are currently not implemented (can still be used by stuffing the command-line)
#    -S, --stuffing=MODE set how to adjust current latency to match desired latency, where
#                            "basic" inserts or deletes audio frames from packet frames with low processor overhead, and
#                            "soxr" uses libsoxr to minimally resample packet frames -- moderate processor overhead.
#                            "soxr" option only available if built with soxr support.
#    -B, --on-start=PROGRAM  run PROGRAM when playback is about to begin.
#    -E, --on-stop=PROGRAM   run PROGRAM when playback has ended.
#                            For -B and -E options, specify the full path to the program, e.g. /usr/bin/logger.
#                            Executable scripts work, but must have the appropriate shebang (#!/bin/sh) in the headline.
#    --password=PASSWORD     require PASSWORD to connect. Default is not to require a password.
#    --logOutputLevel        log the output level setting -- useful for setting maximum volume.
#    -M, --metadata-enable   ask for metadata from the source and process it.
#    --metadata-pipename=PIPE send metadata to PIPE, e.g. --metadata-pipename=/tmp/shairport-sync-metadata.
#                            The default is /tmp/shairport-sync-metadata.
#    -g, --get-coverart      send cover art through the metadata pipe.

# Alsa backend
#    -d output-device    set the output device, default is "default".
#    -c mixer-control    set the mixer control name, default is to use no mixer.
#    -m mixer-device     set the mixer device, default is the output device.
#    -i mixer-index      set the mixer index, default is 0.


##############################################################################################
# goplay / airplay2 goes below
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

