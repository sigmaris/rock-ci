#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cd "${WORKDIR}/u-boot"

if [[ -n "${NO_BUILD_CACHE:-}" \
    || ! -f "build/mmc_idbloader.img" \
    || ! -f "build/spi_idbloader.img" \
    || ! -f "build/u-boot.itb" ]]
then
    if [[ ! -f "$BL31" ]]
    then
        echo "BL31 is missing, build TF-A first."
        exit 1
    fi

    mkdir -p build

    # Clean
    make mrproper

    # Configure
    cp "${SCRIPTPATH}/../configs/ci-rockpro64-rk3399_defconfig" configs/ci-rockpro64-rk3399_defconfig
    make ci-rockpro64-rk3399_defconfig

    # Compile
    make -j$(getconf _NPROCESSORS_ONLN) CROSS_COMPILE=aarch64-linux-gnu-

    # Make images
    tools/mkimage -n rk3399 -T rksd  -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin build/mmc_idbloader.img
    tools/mkimage -n rk3399 -T rkspi -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin build/spi_idbloader.img

    cp u-boot.itb build
fi

echo "::set-output name=artifact_dir::$(pwd)/build"
echo "::set-output name=mmc_idbloader::mmc_idbloader.img"
echo "::set-output name=spi_idbloader::spi_idbloader.img"
echo "::set-output name=itb::u-boot.itb"
