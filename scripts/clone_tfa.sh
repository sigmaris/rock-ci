#!/bin/bash
set -euo pipefail

case "${1:-}" in
get-cache-key)
    git ls-remote --quiet --exit-code "$TF_A_REPO" "$TF_A_REF" | head -n 1 | awk '{print $1;}'
    ;;
*)
    cd "${WORKDIR}"
    git clone --depth 1 --branch "$TF_A_REF" -- "$TF_A_REPO" "arm-trusted-firmware"
    ;;
esac
