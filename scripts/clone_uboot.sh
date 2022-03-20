#!/bin/bash
set -euo pipefail

case "${1:-}" in
get-cache-key)
    git ls-remote --quiet --exit-code "$U_BOOT_REPO" "$U_BOOT_REF" | head -n 1 | awk '{print $1;}'
    ;;
*)
    cd "${WORKDIR}"
    git clone --depth 1 --branch "$U_BOOT_REF" -- "$U_BOOT_REPO" "u-boot"
    ;;
esac
