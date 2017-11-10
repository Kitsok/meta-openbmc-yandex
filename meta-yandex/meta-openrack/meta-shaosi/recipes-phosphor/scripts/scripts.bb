DESCRIPTION = "Script to set MAC and save MAC addresses"

LICENSE = "PD"
LIC_FILES_CHKSUM = "file://setmacs.sh;beginline=1;endline=2;md5=88a069a93872f62fcd7aa03b8d78ae93"
BB_STRICT_CHECKSUM = "0"

SRC_URI = "file://setmacs.sh"
SRC_URI += "file://reset_cb.sh"
SRC_URI += "file://reset_bmc.sh"

SRC_URI += "file://coolingrst"
SRC_URI += "file://getapi"
SRC_URI += "file://getpwm"
SRC_URI += "file://getver"
SRC_URI += "file://pidrst"
SRC_URI += "file://shaosidrst"
SRC_URI += "file://checkmacs"
SRC_URI += "file://reset_eep"

S = "${WORKDIR}"

DEPENDS = "bash "
RDEPENDS_${PN} += "bash "

do_install () {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/setmacs.sh ${D}${sbindir}/setmacs.sh
    install -m 0755 ${WORKDIR}/reset_cb.sh ${D}${sbindir}/reset_cb.sh
    install -m 0755 ${WORKDIR}/reset_bmc.sh ${D}${sbindir}/reset_bmc.sh
    install -m 0755 ${WORKDIR}/coolingrst ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/getapi ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/getpwm ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/getver ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/pidrst ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/shaosidrst ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/checkmacs ${D}${sbindir}/
    install -m 0755 ${WORKDIR}/reset_eep ${D}${sbindir}/
}

FILES_${PN} = "${sbindir}/setmacs.sh ${sbindir}/reset_cb.sh ${sbindir}/reset_bmc.sh \
		${sbindir}/coolingrst ${sbindir}/getapi ${sbindir}/getpwm \
		${sbindir}/getver ${sbindir}/pidrst ${sbindir}/shaosidrst \
		${sbindir}/checkmacs ${sbindir}/reset_eep"

