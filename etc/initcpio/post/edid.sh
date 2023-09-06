#!/bin/sh
if [ -d /usr/lib/firmware/edid/edid.bin ]; then
	cp -r --parents /usr/lib/firmware/edid/edid.bin ${DESTDIR}
fi
exit 0
# drm.edid_firmware=eDP-1:edid/edid.bin
