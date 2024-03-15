#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"

helpers::dir::writable "/tmp"

mdns::start::dbus
mdns::start::avahi

nqptp &

# https://github.com/mikebrady/shairport-sync/blob/master/scripts/shairport-sync.conf
args=(\
  --name "$MOD_MDNS_NAME" \
  --output "$OUTPUT" \
  --mdns avahi \
  --port "${ADVANCED_AIRPLAY_PORT:-7000}" \
  --configfile /config/shairport-sync/main.conf \
)

[ "$LOG_LEVEL" != "debug" ] || args+=(-vvv --statistics)
[ "$LOG_LEVEL" != "info" ] || args+=(-vv)
[ "$LOG_LEVEL" != "warning" ] || args+=(-v)
args+=("$@")
[ ! "$DEVICE" ] || [ "$OUTPUT" != "alsa" ] || args+=(-- -d "$DEVICE")

exec shairport-sync "${args[@]}"
