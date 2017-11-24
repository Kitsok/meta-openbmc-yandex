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
    install -m 0744 ${S}/table.lua ${D}${datadir}/lua/5.1/table.lua
    install -m 0744 ${S}/rack.lua ${D}${datadir}/lua/5.1/rack.lua
    install -m 0744 ${S}/libtobby.lua ${D}${datadir}/lua/5.1/libtobby.lua
}

FILES_${PN} += "${datadir}/lua/5.1/*.lua ${sbindir}/tobby ${systemd_unitdir}/system/obmc-tobby.service"

