#!/bin/bash
set -euo pipefail

print_joined() {
    local IFS="$1"
    shift
    echo "$*"
}

MAKEFLAGS=(CROSS_COMPILE=aarch64-linux-gnu- PLAT=rk3399)
RESULT_DIR=release
if [[ -n "${DEBUG-}" ]]
then
    MAKEFLAGS+=("DEBUG=1")
    RESULT_DIR=debug
fi

case "${1:-}" in
get-cache-key)
    print_joined _ "${MAKEFLAGS[@]}"
    ;;
*)
    cd "${WORKDIR}/arm-trusted-firmware"
    if [[ ! -f "build/rk3399/${RESULT_DIR}/bl31/bl31.elf" || -n "${NO_BUILD_CACHE:-}" ]]
    then
        make realclean
        make "-j$(getconf _NPROCESSORS_ONLN)" "${MAKEFLAGS[@]}" bl31
    fi
    echo "::set-output name=bl31::$(pwd)/build/rk3399/${RESULT_DIR}/bl31/bl31.elf"
    ;;
esac
