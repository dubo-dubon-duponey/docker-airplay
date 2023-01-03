#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"

helpers::dir::writable "/tmp"

helpers::dbus
helpers::avahi

nqptp &

# https://github.com/mikebrady/shairport-sync/blob/master/scripts/shairport-sync.conf
args=(\
  --name "$MDNS_NAME" \
  --output "$OUTPUT" \
  --mdns avahi \
  --port "${PORT:-7000}" \
  --configfile /config/shairport-sync/main.conf \
)

[ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "debug" ] || args+=(-vvv --statistics)
[ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "info" ] || args+=(-vv)
[ "$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')" != "warn" ] || args+=(-v)
args+=("$@")
[ ! "$DEVICE" ] || [ "$OUTPUT" != "alsa" ] || args+=(-- -d "$DEVICE")

exec shairport-sync "${args[@]}"
