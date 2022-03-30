#!/bin/bash
set -euo pipefail

BASE_IMAGE="$1"
BASE_IMAGE_DIR="$(dirname "$BASE_IMAGE")"
BASE_IMAGE_BASENAME="$(basename "$BASE_IMAGE")"
LINUX_IMAGE_DEB="$2"
LINUX_IMAGE_BASENAME="$(basename "$LINUX_IMAGE_DEB")"
KDEB_PKGVERSION="$3"
OUT_DIR="$4"

pushd "$BASE_IMAGE_DIR"
qemu-img create -f qcow2 -b "$BASE_IMAGE_BASENAME" -F qcow2 "${BASE_IMAGE_BASENAME}.snapshot"
popd

sudo modprobe nbd

sudo qemu-nbd --connect /dev/nbd1 "${BASE_IMAGE}.snapshot"
sudo mkdir /mnt/target_image
sudo mount /dev/nbd1p1 /mnt/target_image
sudo systemd-nspawn --bind-ro "${LINUX_IMAGE_DEB}:/${LINUX_IMAGE_BASENAME}" -D /mnt/target_image apt-get install -y "/${LINUX_IMAGE_BASENAME}"
cp "/mnt/target_image/boot/vmlinuz-${KDEB_PKGVERSION}" "/mnt/target_image/boot/initrd.img-${KDEB_PKGVERSION}" "$OUT_DIR"

sudo umount /mnt/target_image
sudo qemu-nbd --disconnect /dev/nbd1
