inherit obmc-phosphor-image_types_uboot

FLASH_UBOOT_OFFSET ?= "0"
FLASH_DTB_OFFSET ?= "512"
FLASH_DTB_SIZE ?= "65536"
FLASH_KERNEL_OFFSET = "576"
FLASH_INITRD_OFFSET ?= "3072"
FLASH_ROFS_OFFSET ?= "4864"
FLASH_RWFS_OFFSET ?= "28672"
RWFS_SIZE ?= "4096"


do_generate_flash_append() {

    pushd .
    cd ${LAYER_DIR}
    ver_yandex=$(git describe --tags || return 0)
    git log --date=local --pretty=format:%cd--%h--%s > ${ddir}/CHANGELOG
    popd

    dtb="zImage-${KERNEL_DEVICETREE}"
    dtbkernel="dtbkernel-${MACHINE}-${DATETIME}"

    dst="${ddir}/${FLASH_IMAGE_NAME}"
    rm -rf $dst
    mk_nor_image ${dst} ${FLASH_SIZE}

    dd if=${ddir}/${uboot} of=${dst} bs=1k conv=notrunc seek=${FLASH_UBOOT_OFFSET}
    dd if=${ddir}/${dtb} of=${dst} bs=1k conv=notrunc seek=${FLASH_DTB_OFFSET}
    dd if=${ddir}/${kernel} of=${dst} bs=1k conv=notrunc seek=${FLASH_KERNEL_OFFSET}
    dd if=${ddir}/${uinitrd} of=${dst} bs=1k conv=notrunc seek=${FLASH_INITRD_OFFSET}
    dd if=${ddir}/${rootfs} of=${dst} bs=1k conv=notrunc seek=${FLASH_ROFS_OFFSET}
    dd if=${ddir}/${rwfs} of=${dst} bs=1k conv=notrunc seek=${FLASH_RWFS_OFFSET}
    dstlink="${ddir}/${FLASH_IMAGE_LINK}"
    rm -rf $dstlink
    ln -sf ${FLASH_IMAGE_NAME} $dstlink

    dd if=${ddir}/${dtb} of=${ddir}/${dtbkernel} bs=${FLASH_DTB_SIZE} conv=sync,notrunc
    dd if=${ddir}/${kernel} of=${ddir}/${dtbkernel} oflag=append conv=notrunc

    rm -rf ${ddir}/image-ukernel > /dev/null 2>&1 || return 0
    ln -sf ${kernel} ${ddir}/image-ukernel
    ln -sf ${dtbkernel} ${ddir}/image-kernel

    tar_appkern="openbmc-0.1.0-${ver_yandex}-app_n_kernel.tar"
    tar_full="openbmc-0.1.0-${ver_yandex}-fullinst.tar"
    tar_fullflash="openbmc-0.1.0-${ver_yandex}-fullflash.tar"
    rm -rf ${ddir}/${tar_appkern}* > /dev/null 2>&1 || return 0
    rm -rf ${ddir}/${tar_full}* > /dev/null 2>&1 || return 0
    rm -rf ${ddir}/${tar_fullflash}* > /dev/null 2>&1 || return 0
    tar -h -cvf ${ddir}/${tar_appkern} -C ${ddir} image-kernel image-initramfs image-rofs CHANGELOG
    tar -h -cvf ${ddir}/${tar_full} -C ${ddir} image-kernel image-initramfs image-rofs image-rwfs image-u-boot CHANGELOG
    tar -h -cvf ${ddir}/${tar_fullflash} -C ${ddir} ${FLASH_IMAGE_NAME}
    gzip ${ddir}/${tar_appkern}
    gzip ${ddir}/${tar_full}
    gzip ${ddir}/${tar_fullflash}
}
