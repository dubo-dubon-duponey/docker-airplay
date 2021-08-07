#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Ensure the tmp folder is writable
[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

rm -Rf /tmp/pid
mkdir -p /tmp/pid

LOG_LEVEL="$(printf "%s" "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')"

args=(--port "$PORT" --output "$OUTPUT" --name "$MDNS_NAME" --use-stderr --mdns tinysvcmdns --configfile /config/shairport-sync/main.conf)
[ "$LOG_LEVEL" != "debug" ] || args+=(${DEBUG:--vvv --statistics})

exec shairport-sync "${args[@]}" "$@"
