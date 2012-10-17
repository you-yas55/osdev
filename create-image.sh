#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo -e "\033[1;31mYou're going to need to run this as root\033[0m" 1>&2
    echo "Additionally, verify that /dev/loop4 is available and that" 1>&2
    echo "/mnt is available for mounting; otherwise, modify the script" 1>&2
    echo "to use alternative loop devices or mount points as needed." 1>&2
    exit 1
fi

DISK=toaru-disk.img
SRCDIR=$1
BOOT=./boot

echo "I will create partitioned, ext2 disk image at $DISK from files in $SRCDIR as well as boot scripts in $BOOT"
read -p "Is this correct? (Y/n)"
if [ "$REPLY" == "n" ] ; then
    echo "Oh, okay, never mind then."
    exit
fi

# Create a 1GiB blank disk image.
dd if=/dev/zero of=$DISK bs=4096 count=262144

echo "Partitioning..."
# Partition it with fdisk.
cat fdisk.conf | fdisk $DISK

echo "Done partition."

# Here's where we need to be root.
losetup /dev/loop1 toaru-disk.img

IMAGE_SIZE=`wc -c < $DISK`
IMAGE_SIZE_SECTORS=`expr $IMAGE_SIZE / 512`
MAPPER_LINE="0 $IMAGE_SIZE_SECTORS linear 7:1 0"

echo "$MAPPER_LINE" | dmsetup create hda

kpartx -a /dev/mapper/hda

mkfs.ext2 /dev/mapper/hda1

mount /dev/mapper/hda1 /mnt

echo "Installing main files."
cp -r $SRCDIR/hdd/* /mnt/

echo "Installing boot files."
cp -r $BOOT /mnt/boot

echo "Installing kernel."
cp -r $SRCDIR/toaruos-kernel /mnt/boot/

echo "Installing grub."
grub-install --boot-directory=/mnt/boot /dev/loop1

./clean-up.sh

echo "Done. You can boot the disk image with qemu now."
