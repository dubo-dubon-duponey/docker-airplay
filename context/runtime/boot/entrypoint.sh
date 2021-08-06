#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# Ensure the tmp folder is writable
[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

# XXX shairport refuses to start if mDNS is not built in
# XXX this hardcodes no password and other settings of shairport-sync
# XXX Metadata: "md=0,1,2" (with coverart) : "md=0,2"
#if [ "${MDNS_ENABLED:-}" == true ]; then
#  goello-server -name "$MDNS_NAME" -host "$MDNS_HOST" -port 5000 -type "$MDNS_TYPE" \
#    -txt '{"sf": "0x4", "fv": "76400.10", "am": "ShairportSync", "vs": "105.1", "tp": "TCP,UDP", "vn": "65537", \
#      "ss": "16", "sr": "44100", "da": "true", "sv": "false", "et": "0,1", "ek": "1", "cn": "0,1", "ch": "2", \
#      "txtvers": "1", "pw": "false"}' &
#fi

# "0" means no debug verbosity, "3" is most verbose. -v -vv -vvv
exec shairport-sync --use-stderr --mdns=tinysvcmdns --configfile=/config/shairport-sync.conf --output=alsa --name="${MDNS_NAME:-TotalesCroquetas}" "$@"
