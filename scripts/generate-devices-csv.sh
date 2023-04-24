#!/bin/sh -u
set -e

RDIR="$(dirname "${0}")"

DEVICES_PATH="${HOME}/Library/Application Support/Garmin/ConnectIQ/Devices"
DEVICES="$(grep -F '<iq:product id="' "${RDIR}/../manifest.xml" | grep -oE '"[^"]*"' | tr -d '"')"


printf "LAUNCHER_ICON_W;LAUNCHER_ICON_H;RESOLUTION_W;RESOLUTION_H;MIN_IQ_VERSION;MAX_IQ_VERSION;MEMORY_LIMIT;DEVICE\n"
for DEVICE in ${DEVICES} ; do
    MEMORY_LIMIT="$(grep -F -B 1 '"type": "datafield"' "${DEVICES_PATH}/${DEVICE}/compiler.json" | head -n 1 | sed -e 's/[^0-9]//g')"
    IQ_VERSIONS="$(grep -F '"connectIQVersion"' "${DEVICES_PATH}/${DEVICE}/compiler.json" | sed -e 's/[^0-9.]//g' | sort -t. -k1,1n -k2,2n -k3,3n -u)"
    LAUNCHER_ICON="$(grep -A 2 '"launcherIcon"' "${DEVICES_PATH}/${DEVICE}/compiler.json")"
    RESOLUTION="$(grep -A 2 '"resolution"' "${DEVICES_PATH}/${DEVICE}/compiler.json")"
    MIN_IQ_VERSION="$(printf "${IQ_VERSIONS}" | head -n 1)"
    MAX_IQ_VERSION="$(printf "${IQ_VERSIONS}" | tail -n 1)"
    LAUNCHER_ICON_W="$(printf "${LAUNCHER_ICON}" | grep -F '"width' | sed -e 's/[^0-9.]//g')"
    LAUNCHER_ICON_H="$(printf "${LAUNCHER_ICON}" | grep -F '"height' | sed -e 's/[^0-9.]//g')"
    RESOLUTION_W="$(printf "${RESOLUTION}" | grep -F '"width' | sed -e 's/[^0-9.]//g')"
    RESOLUTION_H="$(printf "${RESOLUTION}" | grep -F '"height' | sed -e 's/[^0-9.]//g')"
    printf "${LAUNCHER_ICON_W};${LAUNCHER_ICON_H};${RESOLUTION_W};${RESOLUTION_H};${MIN_IQ_VERSION};${MAX_IQ_VERSION};${MEMORY_LIMIT};${DEVICE}\n"
done

exit 0
