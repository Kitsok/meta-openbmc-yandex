DESCRIPTION = "Tobby rack monitoring daemon"
PR = "r1"

inherit obmc-phosphor-license

SRC_URI = "git://github.yandex-team.ru/kitsok/tobby.git"
SRC_URI += "file://obmc-tobby.service"
SRCREV = '${AUTOREV}'

S = "${WORKDIR}/git"

RDEPENDS_${PN} = "luajit lua-curl"

do_install () {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/obmc-tobby.service ${D}${systemd_unitdir}/system/obmc-tobby.service
    install -d ${D}${sbindir}
    install -m 0755 ${S}/tobby.lua ${D}${sbindir}/tobby
    install -d ${D}${datadir}/lua/5.1
    install -m 0744 ${S}/rack.lua ${D}${datadir}/lua/5.1/rack.lua
}

pkg_postinst_${PN} () {
OPTS=""

if [ -n "$D" ]; then
    OPTS="--root=$D"
fi

if type systemctl >/dev/null 2>/dev/null; then
        systemctl $OPTS enable obmc-tobby.service

        if [ -z "$D" -a "enable" = "enable" ]; then
                systemctl restart obmc-tobby.service
        fi
fi
}

FILES_${PN} += "${datadir}/lua/5.1/*.lua ${sbindir}/tobby ${systemd_unitdir}/system/obmc-tobby.service"

