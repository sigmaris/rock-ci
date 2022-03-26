#!/bin/bash
set -euo pipefail

case "${1:-}" in
get-cache-key)
    git ls-remote --quiet --exit-code "$LINUX_REPO" "$LINUX_REF" | head -n 1 | awk '{print $1;}'
    ;;
*)
    cd "${WORKDIR}"
    git clone --depth 1 --branch "$LINUX_REF" -- "$LINUX_REPO" linux
    ;;
esac
