#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

TEMP_WORK="/tmp/rock-ci-$1"
mkdir -p "$TEMP_WORK"
if [ ! -f "$TEMP_WORK"/debian-11-generic-arm64-*.qcow2.snapshot ]
then
    pushd "$SCRIPTPATH" >/dev/null
    gh run download $1 -n imagefiles -D "$TEMP_WORK"
    popd >/dev/null
fi
SNAPSHOT="$(basename "$TEMP_WORK"/debian-11-generic-arm64-*.qcow2.snapshot)"
BASE_IMAGE="${SNAPSHOT%.snapshot}"
if [ ! -f "$BASE_IMAGE" ]
then
    IMG_VER="$(printf '%s' "$BASE_IMAGE" | cut -d - -f 5,6 | cut -d . -f 1)"
    curl --location --output "$BASE_IMAGE" \
        "https://cloud.debian.org/images/cloud/bullseye/${IMG_VER}/${BASE_IMAGE}"
fi
ln -s "$(realpath $BASE_IMAGE)" "${TEMP_WORK}/$BASE_IMAGE"
sudo modprobe nbd

pushd "$TEMP_WORK" >/dev/null
sudo qemu-nbd --connect /dev/nbd1 "$SNAPSHOT"
sudo mkdir -p /mnt/target_image
sudo /sbin/partprobe /dev/nbd1
sudo mount /dev/nbd1p1 /mnt/target_image
sudo mv /mnt/target_image/etc/resolv.conf /mnt/target_image/etc/resolv.conf.bak
sudo systemd-nspawn --resolv-conf=bind-host -D /mnt/target_image
sudo mv -f /mnt/target_image/etc/resolv.conf.bak /mnt/target_image/etc/resolv.conf

sudo umount /mnt/target_image
sudo qemu-nbd --disconnect /dev/nbd1
popd >/dev/null
