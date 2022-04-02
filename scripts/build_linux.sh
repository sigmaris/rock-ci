#!/bin/bash
set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd "$WORKDIR"

if compgen -G "linux-image-*_${ARCH}.deb" > /dev/null && [[ -z "${NO_BUILD_CACHE:-}" ]]
then
    # Use cached build
    LINUX_IMAGE_DEB="$(find . -type f -name "linux-image-*_${ARCH}.deb" -not -name 'linux-image-*-dbg_*_${ARCH}.deb' | head -n 1)"
    VERSION_PART="${LINUX_IMAGE_DEB#./linux-image-}"
    KDEB_PKGVERSION="${VERSION_PART%_*_${ARCH}.deb}"
else
    # Build Linux
    cd linux
    make mrproper
    echo "-g$(git rev-parse --short HEAD)" > .scmversion
    cp "${SCRIPTPATH}/../configs/rockpro64_linux_defconfig" arch/${ARCH}/configs/rockpro64_linux_defconfig
    make rockpro64_linux_defconfig
    export KDEB_PKGVERSION="$(make kernelrelease)"
    make -j$(getconf _NPROCESSORS_ONLN) bindeb-pkg
    LINUX_IMAGE_DEB="linux-image-${KDEB_PKGVERSION}_${KDEB_PKGVERSION}_${ARCH}.deb"
    test -f "../${LINUX_IMAGE_DEB}"
fi

echo "::set-output name=linux_image_deb::${LINUX_IMAGE_DEB}"
echo "::set-output name=kdeb_pkgversion::${KDEB_PKGVERSION}"
