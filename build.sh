#!/bin/sh

usage()
{
    echo "usage: $0 [-a] [-t ufs|zfs]" >&2
    exit 1
}

set -e

KERNFAST=-DKERNFAST
: ${VMFS:=ufs}

while getopts at: o; do
    case "$o" in
    a)
        KERNFAST=
        ;;
    t)
        VMFS=$OPTARG
        if [ "$VMFS" != "ufs" -a "$VMFS" != "zfs" ]; then
            usage
        fi
        ;;
    *)
        usage
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

if [ $VMFS = ufs ]; then
    parttype=freebsd-ufs
    makefs -B little -M 10g -S 512 -Z -o label=VM -o softupdates=1 -o version=2 \
        /root/vm.part ${_FREEBSD_BUILDROOT}
else
    parttype=freebsd-zfs
    makefs -s 15g -t zfs -o poolname=zroot -o bootfs=zroot -o rootpath=/ \
        /root/vm.part ${_FREEBSD_BUILDROOT}
    echo "gpt/rootfs / ufs rw 0 0" > ${_FREEBSD_BUILDROOT}/etc/fstab
fi

mkimg -s gpt -f raw -S 512 -b ${_FREEBSD_BUILDROOT}/boot/pmbr \
    -p freebsd-boot/bootfs:=${_FREEBSD_BUILDROOT}/boot/gptboot \
    -p ${parttype}/rootfs:=/root/vm.part \
    -o ${_SYZKALLER_VM_IMG}
