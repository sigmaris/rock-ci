#!/bin/bash
set -euo pipefail

cd "${WORKDIR}"

git clone --depth 1 --branch "$TF_A_REF" -- "$TF_A_REPO" "arm-trusted-firmware"
