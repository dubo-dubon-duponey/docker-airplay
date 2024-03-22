#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"
# shellcheck source=/dev/null
. "$root/config.sh"

helpers::logger::set "$LOG_LEVEL"

helpers::logger::log INFO "[entrypoint]" "Starting container"

helpers::logger::log DEBUG "[entrypoint]" "Checking directories permissions"
helpers::dir::writable "$XDG_RUNTIME_DIR/dbus" create
helpers::dir::writable "$XDG_RUNTIME_DIR/shairport-sync" create
helpers::dir::writable "$XDG_CACHE_HOME/shairport-sync" create
helpers::dir::writable "$XDG_STATE_HOME/avahi-daemon"

helpers::logger::log INFO "[entrypoint]" "Starting dbus"
mdns::start::dbus "$LOG_LEVEL"

helpers::logger::log INFO "[entrypoint]" "Starting avahi"
mdns::start::avahi "$LOG_LEVEL"

helpers::logger::log INFO "[entrypoint]" "Starting nqptp"

{
  nqptp 2>&1
} > >(helpers::logger::slurp "$LOG_LEVEL" "[nqptp]") \
  && helpers::logger::log INFO "[nqptp]" "nqptp stopped" \
  || helpers::logger::log ERROR "[nqptp]" "nqptp stopped with exit code: $?" &

helpers::logger::log DEBUG "[entrypoint]" "Preparing configuration"

[ "${MOD_MQTT_ENABLED:-}" == true ] && SHAIRPORT_MQTT_ENABLED=yes|| SHAIRPORT_MQTT_ENABLED=no
export SHAIRPORT_GENERAL_NAME="$MOD_MDNS_NAME"
export SHAIRPORT_GENERAL_PORT="${ADVANCED_PORT:-7000}"
export SHAIRPORT_GENERAL_INTERPOLATION="${SHAIRPORT_GENERAL_INTERPOLATION:-basic}"

configuration="$(helpers::config::process SHAIRPORT "general" "mqtt" "dsp" "metadata" "diagnostics")"
printf "%s" "$configuration" > "$XDG_RUNTIME_DIR"/shairport-sync/main.conf
helpers::logger::log DEBUG "[entrypoint]" "Configuration finalized: $configuration"

helpers::logger::log DEBUG "[entrypoint]" "Preparing command"
# https://github.com/mikebrady/shairport-sync/blob/master/scripts/shairport-sync.conf
args=(\
  --configfile "$XDG_RUNTIME_DIR"/shairport-sync/main.conf \
)

# Technically, there is also -vvv - which is "probably too much"
[ "$LOG_LEVEL" != "debug" ] || args+=(-vv --statistics)
[ "$LOG_LEVEL" != "info" ] || args+=(-v)
args+=("$@")
[ ! "$DEVICE" ] || args+=(-- -d "$DEVICE")

helpers::logger::log DEBUG "[entrypoint]" "Command ready to execute - handing over now:"
helpers::logger::log INFO "[entrypoint]" "Starting: shairport-sync ${args[*]}"
# Slurp logs at log_level and relog properly
{
  exec shairport-sync "${args[@]}" 2>&1
} > >(helpers::logger::slurp "$LOG_LEVEL" "[shairport-sync]")
