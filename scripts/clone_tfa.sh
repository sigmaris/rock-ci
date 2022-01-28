#!/bin/bash
set -euo pipefail

. ./defaults

cd "${WORKDIR}"

# Fallbacks to defaults
if [[ -z "${TF_A_REPO-}" ]]
then
    TF_A_REPO="$DEF_TF_A_REPO"
fi
if [[ -z "${TF_A_REF-}" ]]
then
    TF_A_REF="$DEF_TF_A_REF"
fi

git clone --depth 1 --branch "$TF_A_REF" -- "$TF_A_REPO" "arm-trusted-firmware"
