#!/bin/bash
set -euo pipefail

. ./defaults

cd "${WORKDIR}"

# Fallbacks to defaults
if [[ -z "${U_BOOT_REPO-}" ]]
then
    U_BOOT_REPO="$DEF_U_BOOT_REPO"
fi
if [[ -z "${U_BOOT_REF-}" ]]
then
    U_BOOT_REF="$DEF_U_BOOT_REF"
fi

git clone --depth 1 --branch "$U_BOOT_REF" -- "$U_BOOT_REPO" "u-boot"
