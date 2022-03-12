#!/bin/bash
set -euo pipefail

. ./defaults

BOARD_NAME="${BOARD_NAME_WD:-$DEF_BOARD_NAME}"
TF_A_REPO="${TF_A_REPO_WD:-$DEF_TF_A_REPO}"
TF_A_REF="${TF_A_REF_WD:-$DEF_TF_A_REF}"
U_BOOT_REPO="${U_BOOT_REPO_WD:-$DEF_U_BOOT_REPO}"
U_BOOT_REF="${U_BOOT_REF_WD:-$DEF_U_BOOT_REF}"

echo "::set-output name=board_name::${BOARD_NAME}"
echo "::set-output name=tf_a_repo::${TF_A_REPO}"
echo "::set-output name=tf_a_ref::${TF_A_REF}"
echo "::set-output name=u_boot_repo::${U_BOOT_REPO}"
echo "::set-output name=u_boot_ref::${U_BOOT_REF}"