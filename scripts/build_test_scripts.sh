#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cd "$WORKDIR"

# Make flash scripts
"${SCRIPTPATH}/gen_test_scr.py" -i "${TFTP_RUN_DIR}/mmc_idbloader.img" -u "${TFTP_RUN_DIR}/u-boot.itb" --emmc emmc_test.scr
"${SCRIPTPATH}/gen_test_scr.py" -i "${TFTP_RUN_DIR}/mmc_idbloader.img" -u "${TFTP_RUN_DIR}/u-boot.itb" --sdcard sd_test.scr
mkimage -A arm -T script -d emmc_test.scr emmc_test.scr.uimg
mkimage -A arm -T script -d sd_test.scr sd_test.scr.uimg

echo "::set-output name=artifact_dir::$(pwd)"
echo "::set-output name=emmc_test_scr::emmc_test.scr.uimg"
echo "::set-output name=sd_test_scr::sd_test.scr.uimg"
