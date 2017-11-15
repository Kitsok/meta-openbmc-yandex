SUMMARY = "A Lua cURL library"
DESCRIPTION = "A Lua cURL library"

HOMEPAGE = "https://github.com/Lua-cURL/Lua-cURLv3"
inherit obmc-phosphor-license

SRC_URI = "file://lua-curl"

S = "${WORKDIR}/lua-curl"

SYSROOTS = "${STAGING_DIR}/${MACHINE}"

DEPENDS = "luajit curl boost"
luadir = "/lua/5.1"

MAKE_FLAGS = "'PREFIX=${D}${prefix}' \
'CC=${CC}' \
'CFLAGS=-I${SYSROOTS}${includedir}/luajit-2.1' \
"

do_compile () {
    oe_runmake ${MAKE_FLAGS} 
}

do_install () {
    oe_runmake ${MAKE_FLAGS} DESTDIR=${D} install
}

FILES_${PN} += "${libdir}${luadir}/*.so ${datadir}/lua/5.1/cURL/*.lua ${datadir}/lua/5.1/cURL.lua \
		${datadir}/lua/5.1/cURL/impl/cURL.lua"

