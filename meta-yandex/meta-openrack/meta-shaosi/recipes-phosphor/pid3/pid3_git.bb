DESCRIPTION = "PID regulator"
LICENSE = "PD"
LIC_FILES_CHKSUM = "file://main.cpp;beginline=1;endline=2;md5=ed0443b95075d48d7a632144acce0ac0"
BB_STRICT_CHECKSUM = "0"

#SRC_URI = "git://github.yandex-team.ru/kitsok/pid3.git;branch=RND-614"
SRC_URI = "git://github.yandex-team.ru/kitsok/pid3.git"

SRC_URI += "file://obmc-pid3.service"
SRC_URI += "file://pid3_wrapper"
SRC_URI += "file://safefans.sh"
SRCREV = '${AUTOREV}'

S = "${WORKDIR}/git"

DEPENDS = "curlpp bash "
RDEPENDS_${PN} += "bash "

inherit cmake

do_install_append () {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/obmc-pid3.service ${D}${systemd_unitdir}/system/obmc-pid3.service
    install -m 0755 ${WORKDIR}/pid3_wrapper ${D}${sbindir}/pid3_wrapper
    install -m 0755 ${WORKDIR}/safefans.sh ${D}${sbindir}/safefans.sh
}

pkg_postinst_${PN} () {
OPTS=""

if [ -n "$D" ]; then
    OPTS="--root=$D"
fi

if type systemctl >/dev/null 2>/dev/null; then
	systemctl $OPTS enable obmc-pid3.service

	if [ -z "$D" -a "enable" = "enable" ]; then
		systemctl restart obmc-pid3.service
	fi
fi
}

FILES_${PN} = "${sbindir}/pid3 \
               ${sbindir}/pid3_wrapper \
               ${sysconfdir}/pid3.conf \
               ${sbindir}/safefans.sh \
               ${sysconfdir}/systemd/system/obmc-pid3.service.d \
               ${systemd_unitdir}/system/obmc-pid3.service \
"
