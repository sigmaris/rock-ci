#!/bin/bash
set -euo pipefail

cd "${WORKDIR}"

git clone --depth 1 --branch "$U_BOOT_REF" -- "$U_BOOT_REPO" "u-boot"
