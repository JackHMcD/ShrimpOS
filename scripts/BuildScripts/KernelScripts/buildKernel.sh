#!/bin/bash

set -x
set -e

# build Linux-libre, with ath9k_htc firmware and initramfs built in


# This file is part of PrawnOS (https://www.prawnos.com)
# Copyright (c) 2018-2020 Hal Emmerich <hal@halemmerich.com>

# PrawnOS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.

# PrawnOS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with PrawnOS.  If not, see <https://www.gnu.org/licenses/>.

if [ -z "$1" ]
then
    echo "No kernel version supplied"
    exit 1
fi
if [ -z "$2" ]
then
    echo "No resources directory"
    exit 1
fi
if [ -z "$3" ]
then
    echo "No build directory supplied"
    exit 1
fi
if [ -z "$4" ]
then
    echo "No PrawnOS initramfs supplied"
    exit 1
fi

KVER=$1
RESOURCES=$2
BUILD_DIR=$3
INITRAMFS=$4

cd $BUILD_DIR
make mrproper

#copy in the resources, initramfs
cp $INITRAMFS .
cp $RESOURCES/config .confige
cp $RESOURCES/kernel.its .
mkdir brcm
cp $RESOURCES/brcmfmac4354-sdio.bin brcm/
cp $RESOURCES/brcmfmac4354-sdio.txt brcm/
cp $RESOURCES/brcmfmac4354-sdio.txt 'brcm/brcmfmac4354-sdio.google,veyron-minnie-rev4.txt'
make -j $(($(nproc) +1))  CROSS_COMPILE=arm-none-eabi- ARCH=arm zImage modules dtbs
mkimage -D "-I dts -O dtb -p 2048" -f kernel.its vmlinux.uimg
dd if=/dev/zero of=bootloader.bin bs=512 count=1
vbutil_kernel --pack vmlinux.kpart \
              --version 1 \
              --vmlinuz vmlinux.uimg \
              --arch arm \
              --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
              --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
              --config $RESOURCES/cmdline \
              --bootloader bootloader.bin

RESULT=$?
if [ ! $RESULT -eq 0 ]; then
    rm -f vmlinux.kpart
fi
