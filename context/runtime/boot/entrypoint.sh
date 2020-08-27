#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

NAME=${NAME:-no name}

exec shairport-sync --use-stderr --mdns=tinysvcmdns --configfile=/config/shairport-sync.conf --output=alsa --name="$NAME" "$@"
