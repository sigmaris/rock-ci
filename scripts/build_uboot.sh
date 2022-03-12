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

# Make flash scripts
"${SCRIPTPATH}/gen_test_scr.py" -i "${TFTP_RUN_DIR}/mmc_idbloader.img" -u "${TFTP_RUN_DIR}/u-boot.itb" --emmc emmc_test.scr
"${SCRIPTPATH}/gen_test_scr.py" -i "${TFTP_RUN_DIR}/mmc_idbloader.img" -u "${TFTP_RUN_DIR}/u-boot.itb" --sdcard sd_test.scr
tools/mkimage -A arm -T script -d emmc_test.scr emmc_test.scr.uimg
tools/mkimage -A arm -T script -d sd_test.scr sd_test.scr.uimg

echo "::set-output name=artifact_dir::$(pwd)"
echo "::set-output name=mmc_idbloader::mmc_idbloader.img"
echo "::set-output name=spi_idbloader::spi_idbloader.img"
echo "::set-output name=itb::u-boot.itb"
echo "::set-output name=emmc_test_scr::emmc_test.scr.uimg"
echo "::set-output name=sd_test_scr::sd_test.scr.uimg"
