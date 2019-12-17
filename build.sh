#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export TITLE="Shairport Sync"
export DESCRIPTION="A dubo image for Shairport Sync"
export IMAGE_NAME="shairport-sync"

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh"
