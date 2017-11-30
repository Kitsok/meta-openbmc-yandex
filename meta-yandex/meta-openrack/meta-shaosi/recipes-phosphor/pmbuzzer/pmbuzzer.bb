DESCRIPTION = "Pmbuzzer PSU monitoring daemon"
PR = "r1"

inherit obmc-phosphor-license

SRC_URI = "file://obmc-pmbuzzer.service"
SRC_URI += "file://i2c.lua"
SRC_URI += "file://pmbus.lua"
SRC_URI += "file://pmbuzzer.lua"
SRCREV = '${AUTOREV}'

S = "${WORKDIR}"

RDEPENDS_${PN} = "luajit lua-curl"

do_install () {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/obmc-pmbuzzer.service ${D}${systemd_unitdir}/system/obmc-pmbuzzer.service
    install -d ${D}${sbindir}
    install -m 0755 ${S}/pmbuzzer.lua ${D}${sbindir}/pmbuzzer
    install -d ${D}${datadir}/lua/5.1
    install -m 0744 ${S}/i2c.lua ${D}${datadir}/lua/5.1/i2c.lua
    install -m 0744 ${S}/pmbus.lua ${D}${datadir}/lua/5.1/pmbus.lua
}

pkg_postinst_${PN} () {
OPTS=""

if [ -n "$D" ]; then
    OPTS="--root=$D"
fi

if type systemctl >/dev/null 2>/dev/null; then
        systemctl $OPTS enable obmc-pmbuzzer.service

        if [ -z "$D" -a "enable" = "enable" ]; then
                systemctl restart obmc-pmbuzzer.service
        fi
fi
}

FILES_${PN} += "${datadir}/lua/5.1/*.lua ${sbindir}/pmbuzzer ${systemd_unitdir}/system/obmc-pmbuzzer.service"

