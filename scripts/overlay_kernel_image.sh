#!/bin/bash
set -euo pipefail

BASE_IMAGE="$1"
BASE_IMAGE_DIR="$(dirname "$BASE_IMAGE")"
BASE_IMAGE_BASENAME="$(basename "$BASE_IMAGE")"
LINUX_IMAGE_DEB="$2"
LINUX_IMAGE_BASENAME="$(basename "$LINUX_IMAGE_DEB")"
KDEB_PKGVERSION="$3"
OUT_DIR="$4"
PACKAGES="gammastep nbd-client python3-pytest"

pushd "$BASE_IMAGE_DIR"
qemu-img create -f qcow2 -b "$BASE_IMAGE_BASENAME" -F qcow2 "${BASE_IMAGE_BASENAME}.snapshot"
popd

sudo modprobe nbd

sudo qemu-nbd --connect /dev/nbd1 "${BASE_IMAGE}.snapshot"
sudo mkdir -p /mnt/target_image
sudo /sbin/partprobe /dev/nbd1
sudo mount /dev/nbd1p1 /mnt/target_image
sudo mv /mnt/target_image/etc/resolv.conf /mnt/target_image/etc/resolv.conf.bak
sudo systemd-nspawn --resolv-conf=bind-host --bind-ro "$(realpath "$LINUX_IMAGE_DEB"):/${LINUX_IMAGE_BASENAME}" -D /mnt/target_image /bin/sh -c "apt-get update && apt-get install -y $PACKAGES /${LINUX_IMAGE_BASENAME}"
sudo mv -f /mnt/target_image/etc/resolv.conf.bak /mnt/target_image/etc/resolv.conf
sudo rm "/mnt/target_image/${LINUX_IMAGE_BASENAME}"
cp "/mnt/target_image/boot/vmlinuz-${KDEB_PKGVERSION}" "/mnt/target_image/boot/initrd.img-${KDEB_PKGVERSION}" "/mnt/target_image/usr/lib/linux-image-${KDEB_PKGVERSION}/rockchip/rk3399-rockpro64.dtb" "$OUT_DIR"

sudo umount /mnt/target_image
sudo qemu-nbd --disconnect /dev/nbd1
