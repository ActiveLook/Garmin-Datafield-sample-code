#!/bin/sh -u
set -e

RDIR="$(dirname "${0}")"

DEVICES_PATH="${HOME}/Library/Application Support/Garmin/ConnectIQ/Devices"
DEVICES="$(grep -F '<iq:product id="' "${RDIR}/../manifest.xml" | grep -oE '"[^"]*"' | tr -d '"')"


printf "lh;lw;www;hhh;qualifier\n" > "$(dirname "${0}")/devices.csv"

printf '65;65;208;208;base\n' >> "$(dirname "${0}")/devices.csv"
printf '40;40;218;218;round\n' >> "$(dirname "${0}")/devices.csv"
printf '40;40;215;180;semiround\n' >> "$(dirname "${0}")/devices.csv"
printf '33;40;148;205;rectangle\n' >> "$(dirname "${0}")/devices.csv"
printf '40;40;240;240;round-240x240\n' >> "$(dirname "${0}")/devices.csv"
printf '35;35;260;260;round-260x260\n' >> "$(dirname "${0}")/devices.csv"
printf '40;40;280;280;round-280x280\n' >> "$(dirname "${0}")/devices.csv"
printf '60;60;390;390;round-390x390\n' >> "$(dirname "${0}")/devices.csv"
printf '35;35;200;265;rectangle-200x265\n' >> "$(dirname "${0}")/devices.csv"
printf '35;35;230;303;rectangle-230x303\n' >> "$(dirname "${0}")/devices.csv"
printf '35;35;246;322;rectangle-246x322\n' >> "$(dirname "${0}")/devices.csv"
printf '36;36;282;470;rectangle-282x470\n' >> "$(dirname "${0}")/devices.csv"


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
    printf "${LAUNCHER_ICON_H};${LAUNCHER_ICON_W};${RESOLUTION_W};${RESOLUTION_H};${DEVICE}\n" >> "$(dirname "${0}")/devices.csv"
done

exit 0
