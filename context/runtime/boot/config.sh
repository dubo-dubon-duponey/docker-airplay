#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

helpers::config::serialization::kv::equal(){
  local key="$1"
  local value="$2"
  printf "%s" "$value" | grep -qE "^[0-9.-]+$" || value="$(printf "\"%s\"" "$(printf "%s" "$value" | sed -E 's/"/\\"/g')")"
  printf "%s = %s\n" "$key" "$value"
}

helpers::config::slurp(){
  local top="$1"
  local key_value_serialization="$2"
  local line
  local var

  while read -r line; do
    key="$(printf "_mapping_%s_%s" "$top" "${line%%_*}" | tr '[:upper:]' '[:lower:]')"
    sub="${line#*_}"
    value="${sub#*=}"
    sub="$(printf "%s" "${sub%%=*}" | tr '[:upper:]' '[:lower:]')"
    declare -n var="$key"
    var+=("$($key_value_serialization "$sub" "$value")")
  done < <(env | grep "$top"_ | sed -E "s/${top}_//")
}

helpers::config::dump(){
  local top="$1"
  shift
  local sections=("$@")
  local section
  local conf
  local var

  for section in "${sections[@]}"; do
    echo "$section = {"
    declare -n var="$(printf "_mapping_%s_%s" "$top" "${section}" | tr '[:upper:]' '[:lower:]')"
    for conf in "${var[@]}"; do
      echo "  $conf"
    done
    echo "};"
  done
}

export SHAIRPORT_MQTT_PUBLISH_COVER="${SHAIRPORT_MQTT_PUBLISH_COVER:-yes}"
export SHAIRPORT_MQTT_ENABLE_REMOTE="${SHAIRPORT_MQTT_ENABLE_REMOTE:-yes}"

# This should be MOD once we have a proven generalization
# Maybe we rather need ghost for this though, and let airplay interact with localhost:1883 without anything else
export SHAIRPORT_MQTT_PORT="${SHAIRPORT_MQTT_PORT:-1883}"
#SHAIRPORT_MQTT_HOSTNAME
#SHAIRPORT_MQTT_USERNAME
#SHAIRPORT_MQTT_PASSWORD
#SHAIRPORT_MQTT_CAFILE
#SHAIRPORT_MQTT_CERTFILE
#SHAIRPORT_MQTT_KEYFILE

# Useful for magnetar
export SHAIRPORT_GENERAL_IGNORE_VOLUME_CONTROL="${SHAIRPORT_GENERAL_IGNORE_VOLUME_CONTROL:-no}"
# Useful for nightingale
export SHAIRPORT_GENERAL_PLAYBACK_MODE="${SHAIRPORT_GENERAL_PLAYBACK_MODE:-stereo}"
# Useful for all
export SHAIRPORT_GENERAL_DEFAULT_VOLUME="${SHAIRPORT_GENERAL_DEFAULT_VOLUME:--20.0}"

export SHAIRPORT_DSP_CONVOLUTION="${SHAIRPORT_DSP_CONVOLUTION:-yes}"
# Useful for nightingale and dacodac
#SHAIRPORT_DSP_CONVOLUTION_IR_FILE

# shellcheck disable=SC2034
export SHAIRPORT_GENERAL_OUTPUT_BACKEND="alsa"
# shellcheck disable=SC2034
export SHAIRPORT_GENERAL_MDNS_BACKEND="avahi"
# Just airplay 1
export SHAIRPORT_GENERAL_UDP_PORT_BASE="6000"
export SHAIRPORT_GENERAL_UDP_PORT_RANGE="10"

export SHAIRPORT_METADATA_COVER_ART_CACHE_DIRECTORY="$XDG_CACHE_HOME/shairport-sync"
export SHAIRPORT_METADATA_PIPE_NAME="$XDG_RUNTIME_DIR/shairport-sync/metadata"


export SHAIRPORT_DIAGNOSTICS_LOG_SHOW_TIME_SINCE_STARTUP="${SHAIRPORT_DIAGNOSTICS_LOG_SHOW_TIME_SINCE_STARTUP:-no}"
export SHAIRPORT_DIAGNOSTICS_LOG_SHOW_TIME_SINCE_LAST_MESSAGE="${SHAIRPORT_DIAGNOSTICS_LOG_SHOW_TIME_SINCE_LAST_MESSAGE:-no}"
export SHAIRPORT_DIAGNOSTICS_LOG_SHOW_FILE_AND_LINE="${SHAIRPORT_DIAGNOSTICS_LOG_SHOW_FILE_AND_LINE:-no}"
export SHAIRPORT_DIAGNOSTICS_LOG_OUTPUT_TO="stderr"

helpers::config::process(){
  helpers::config::slurp SHAIRPORT helpers::config::serialization::kv::equal
  helpers::config::dump SHAIRPORT "general" "mqtt" "dsp" "metadata" "diagnostics"
}
