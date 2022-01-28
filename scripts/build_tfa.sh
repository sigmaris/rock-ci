#!/bin/bash
set -euo pipefail

cd "${WORKDIR}/arm-trusted-firmware"

make realclean

MAKEFLAGS=("-j$(getconf _NPROCESSORS_ONLN)" CROSS_COMPILE=aarch64-linux-gnu- PLAT=rk3399)
RESULT_DIR=release
if [[ -n "${DEBUG-}" ]]
then
    MAKEFLAGS+=("DEBUG=1")
    RESULT_DIR=debug
fi
make "${MAKEFLAGS[@]}" bl31

echo "::set-output name=bl31::$(pwd)/build/rk3399/${RESULT_DIR}/bl31/bl31.elf"
