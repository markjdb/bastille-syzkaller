#!/bin/sh

set -e

KERNFAST=-DKERNFAST

while getopts a o; do
    case "$o" in
    a)
        KERNFAST=
        ;;
    *)
        exit 1
        ;;
    esac
    shift $((OPTIND - 1))
done

cd ${_FREEBSD_SRC_PATH}
nice -n 20 make -s -j$(sysctl -n hw.ncpu) buildkernel \
    KERNCONF=SYZKALLER KERNCONFDIR=/root SRCCONF=${_FREEBSD_BUILD_SRCCONF} \
    $KERNFAST
make -s -j$(sysctl -n hw.ncpu) installkernel \
    KERNCONF=SYZKALLER KERNCONFDIR=/root DESTDIR=${_FREEBSD_BUILDROOT} \
    SRCCONF=${_FREEBSD_BUILD_SRCCONF}

makefs -B little -M 10g -S 512 -Z -o label=VM -o softupdates=1 -o version=2 \
    /root/vm.part ${_FREEBSD_BUILDROOT}
mkimg -s gpt -f raw -S 512 -b ${_FREEBSD_BUILDROOT}/boot/pmbr \
    -p freebsd-boot/bootfs:=${_FREEBSD_BUILDROOT}/boot/gptboot \
    -p freebsd-ufs/rootfs:=/root/vm.part \
    -o ${_SYZKALLER_VM_IMG}
