#!/bin/bash
set -euo pipefail

cd "${WORKDIR}/u-boot"

if ! [[ -f "$BL31" ]]
then
    echo "BL31 is missing, build TF-A first."
    exit 1
fi
