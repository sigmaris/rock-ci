#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cd "${WORKDIR}/u-boot"

if ! [[ -f "$BL31" ]]
then
    echo "BL31 is missing, build TF-A first."
    exit 1
fi

# Clean
make mrproper

# Configure
cp "${SCRIPTPATH}/../configs/ci-rockpro64-rk3399_defconfig" configs/ci-rockpro64-rk3399_defconfig
make ci-rockpro64-rk3399_defconfig

# Compile
make -j$(getconf _NPROCESSORS_ONLN) CROSS_COMPILE=aarch64-linux-gnu-

# Make images
tools/mkimage -n rk3399 -T rksd  -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin mmc_idbloader.img
tools/mkimage -n rk3399 -T rkspi -d tpl/u-boot-tpl.bin:spl/u-boot-spl.bin spi_idbloader.img

# Make flash script
"${SCRIPTPATH}/gen_test_scr.py" -i mmc_idbloader.img mmc_test.scr
tools/mkimage -A arm -T script -d mmc_test.scr boot.scr.uimg

echo "::set-output name=mmc_idbloader::$(pwd)/mmc_idbloader.img"
echo "::set-output name=spi_idbloader::$(pwd)/spi_idbloader.img"
echo "::set-output name=itb::$(pwd)/u-boot.itb"
echo "::set-output name=test_scr::$(pwd)/boot.scr.uimg"
