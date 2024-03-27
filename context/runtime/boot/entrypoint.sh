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

# shellcheck disable=SC2015
{
  nqptp 2>&1
} > >(helpers::logger::slurp "$LOG_LEVEL" "[nqptp]") \
  && helpers::logger::log INFO "[nqptp]" "nqptp stopped" \
  || helpers::logger::log ERROR "[nqptp]" "nqptp stopped with exit code: $?" &

helpers::logger::log DEBUG "[entrypoint]" "Preparing configuration"

# Connect specific env variables to shairport scheme
export SHAIRPORT_GENERAL_NAME="$MOD_MDNS_NAME"
export SHAIRPORT_GENERAL_PORT="${ADVANCED_PORT:-7000}"
# Useful for nightingale
export SHAIRPORT_GENERAL_PLAYBACK_MODE="${MOD_AUDIO_MODE:-stereo}"
# Useful for all
export SHAIRPORT_GENERAL_DEFAULT_AIRPLAY_VOLUME="${MOD_AUDIO_VOLUME_DEFAULT:--20.0}"
# Useful for magnetar
[ "${MOD_AUDIO_VOLUME_IGNORE:-}" == true ] && SHAIRPORT_GENERAL_IGNORE_VOLUME_CONTROL=yes || SHAIRPORT_GENERAL_IGNORE_VOLUME_CONTROL=no
export SHAIRPORT_GENERAL_IGNORE_VOLUME_CONTROL

export SHAIRPORT_ALSA_OUTPUT_DEVICE="${MOD_AUDIO_DEVICE:-}"
export SHAIRPORT_ALSA_MIXER_CONTROL_NAME="${MOD_AUDIO_MIXER:-}"

[ "${MOD_MQTT_ENABLED:-}" == true ] && SHAIRPORT_MQTT_ENABLED=yes || SHAIRPORT_MQTT_ENABLED=no
export SHAIRPORT_MQTT_ENABLED

SHAIRPORT_DIAGNOSTICS_STATISTICS="no"
case "$LOG_LEVEL" in
  "debug")
    SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY="2"
    SHAIRPORT_DIAGNOSTICS_STATISTICS="yes"
  ;;
  "info")
    SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY="1"
  ;;
  "warn")
    SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY="0"
  ;;
  "error")
    SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY="0"
  ;;
  *)
    SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY="0"
  ;;
esac

export SHAIRPORT_DIAGNOSTICS_STATISTICS
export SHAIRPORT_DIAGNOSTICS_LOG_VERBOSITY

configuration="$(helpers::config::process SHAIRPORT "general" "mqtt" "dsp" "metadata" "diagnostics")"
printf "%s" "$configuration" > "$XDG_RUNTIME_DIR"/shairport-sync/main.conf
helpers::logger::log DEBUG "[entrypoint]" "Configuration finalized: $configuration"

helpers::logger::log DEBUG "[entrypoint]" "Preparing command"
# https://github.com/mikebrady/shairport-sync/blob/master/scripts/shairport-sync.conf
args=(--configfile "$XDG_RUNTIME_DIR"/shairport-sync/main.conf "$@")

helpers::logger::log DEBUG "[entrypoint]" "Command ready to execute - handing over now:"
helpers::logger::log INFO "[entrypoint]" "Starting: shairport-sync ${args[*]}"
# Slurp logs at log_level and relog properly
{
  exec shairport-sync "${args[@]}" 2>&1
} > >(helpers::logger::slurp "$LOG_LEVEL" "[shairport-sync]")
