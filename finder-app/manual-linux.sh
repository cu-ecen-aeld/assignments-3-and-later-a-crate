#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.
set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    ARCH=${ARCH} make defconfig
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make ${MAKEOPTS:=}
fi

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p ${OUTDIR}/rootfs/{bin,boot,dev,etc,home,lib,lib64,sys,proc,root,sbin,sys,tmp,var/log,usr/bin,usr/sbin,usr/lib}

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make ${MAKEOPTS:=} distclean
    CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make ${MAKEOPTS:=} defconfig
    CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make ${MAKEOPTS:=}
else
    cd busybox
fi

make ${MAKEOPTS:=} CONFIG_PREFIX=${OUTDIR}/rootfs/ ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install
cd ${OUTDIR}/rootfs

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep 'program interpreter'
cp --dereference $(${CROSS_COMPILE}gcc -print-sysroot)/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/ld-linux-aarch64.so.1
cp --dereference $(${CROSS_COMPILE}gcc -print-sysroot)/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib64/ld-linux-aarch64.so.1
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library" | tr -d []
for lib in $(${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library" | tr -d []); do
    path=$(find $(${CROSS_COMPILE}gcc -print-sysroot) -name $lib)
    if [ "$path" == "" ]; then continue; fi
    to=$(echo $path | sed "s#$(${CROSS_COMPILE}gcc -print-sysroot)#${OUTDIR}/rootfs#g")
    echo "$path => $to"
    cp --dereference $path $to
done

cd $FINDER_APP_DIR
make clean
CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} make
cp ./{writer,finder.sh,finder-test.sh,autorun-qemu.sh} ${OUTDIR}/rootfs/home/
cp -r ../conf ${OUTDIR}/rootfs/home/

cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/console c 5 1

echo "Packing initrd"
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
