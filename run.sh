#!/bin/sh -u
set -e

RDIR="$(dirname "${0}")"
JAVA_HOME=$(/usr/libexec/java_home -v1.8)
CIQ_PATH="$(cat ${HOME}/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg)/bin"

export PATH="${PATH}:${CIQ_PATH}"

MINSDKVERSION="$(grep -oE 'minSdkVersion="[^"]*"' "${RDIR}/manifest.xml" | grep -oE '"[^"]*"' | tr -d '"')"
DEVICES="$(grep -F '<iq:product id="' "${RDIR}/manifest.xml" | grep -oE '"[^"]*"' | tr -d '"')"
NB_DEVICES="$(printf "${DEVICES}\n" | wc -l)"
CURRENT_DEVICE="$(printf "${DEVICES}\n" | head -n $(( 1 + ${RANDOM} % ${NB_DEVICES} )) | tail -n 1)"

SIMULATOR_INI="${HOME}/Library/Application Support/Garmin/ConnectIQ/simulator.ini"
TTY_MODEM="$(ls /dev/tty.usbmodem* 2> /dev/null | head -n 1)"

CURRENT_OPTS=
function _help() {
    printf "${0} [<options> command] ... [<options> command]
  Commands:
    help     Display this help message
    task     Run next options and commands as a nodemon task
    clean    Remove bin directory
    doc      Generate documentation
    pack     Build the datafield as a Connect IQ package
    build    Build the datafield for a device
    run      Run in the simulator
    debug    Debug with the simulator
    simu     Start the simulator

  The list of the available device for the datafield is:
"
    printf "${DEVICES}" | xargs -L 5 | column -t
    printf "\n"
}

function _task() {
    printf " Task  / Commands: ${@} / Options: ${CURRENT_OPTS}\n"
    npx nodemon -e "mc,sh" -d 1 --exec "${0}" -- "${@}" "&"
}

function _simu() {
    if ! [ -f "${SIMULATOR_INI}" ] ; then
        touch "${SIMULATOR_INI}"
    fi
    if [ -n "${TTY_MODEM}" ] ; then
        if ! grep -Fxq "NordicPort=${TTY_MODEM}" "${SIMULATOR_INI}" ; then
            printf "NordicPort=${TTY_MODEM}\n" > "${SIMULATOR_INI}"
        fi
    fi
    pgrep -q simulator || connectiq
}

function _clean() {
    printf " Clean / Options: ${CURRENT_OPTS}\n"
    rm -f "${SIMULATOR_INI}"
    pkill simulator || true
    rm -rf "${RDIR}/bin"
}

function _doc() {
    printf " Doc   / Options: ${CURRENT_OPTS}\n"
    monkeydoc ${CURRENT_OPTS} \
        -Wall \
        --api-mir "${CIQ_PATH}/api.mir" \
        --output-path "${RDIR}/bin/doc/" \
        "${RDIR}/source/"*".mc"
}

function _pack() {
    printf " Pack  / Options: ${CURRENT_OPTS}\n"
    monkeyc ${CURRENT_OPTS} \
        --release \
        --package-app \
        --warn \
        --typecheck   3 \
        --api-level   "${MINSDKVERSION}" \
        --jungles     "${RDIR}/monkey.jungle;${RDIR}/barrels.jungle" \
        --output      "${RDIR}/bin/ActiveLookDataField.iq" \
        --private-key "${RDIR}/key/GarminDeveloperKey"
}

function _build() {
    printf " Build / Device: ${CURRENT_DEVICE} / Options: ${CURRENT_OPTS}\n"
    monkeyc ${CURRENT_OPTS} \
        --warn \
        --typecheck   0 \
        --device      "${CURRENT_DEVICE}" \
        --jungles     "${RDIR}/monkey.jungle;${RDIR}/barrels.jungle" \
        --output      "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg" \
        --private-key "${RDIR}/key/GarminDeveloperKey"
}

function _run() {
    printf " Run   / Device: ${CURRENT_DEVICE} / Options: ${CURRENT_OPTS}\n"
    _simu
    if ! [ -f "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg" ] ; then
        _build
    fi
    monkeydo ${CURRENT_OPTS} \
        "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg" \
        ${CURRENT_DEVICE}
}

function _debug() {
    printf " Debug / Device: ${CURRENT_DEVICE} / Options: ${CURRENT_OPTS}\n"
    _simu
    if ! [ -f "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg" ] ; then
        _build
    fi
    mdd ${CURRENT_OPTS} \
        --device      "${CURRENT_DEVICE}" \
        --executable  "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg" \
        --debug-xml   "${RDIR}/bin/ActiveLookDataField-${CURRENT_DEVICE}.prg.debug.xml"
}

function _device() {
    CURRENT_DEVICE="${1}"
    if ! printf "${DEVICES}" | grep -Fxq "${CURRENT_DEVICE}" ; then
        _help
        exit 1
    fi
}

while [ ${#} -gt 0 ] ; do
    case "${1}" in
        task)  shift ; _task  "${@}" ; exit 0 ;;
        help)  shift ; _help  ; CURRENT_OPTS= ;;
        clean) shift ; _clean ; CURRENT_OPTS= ;;
        doc)   shift ; _doc   ; CURRENT_OPTS= ;;
        pack)  shift ; _pack  ; CURRENT_OPTS= ;;
        build) shift ; _build ; CURRENT_OPTS= ;;
        run)   shift ; _run   ; CURRENT_OPTS= ;;
        debug) shift ; _debug ; CURRENT_OPTS= ;;
        simu)  shift ; _simu  ; CURRENT_OPTS= ;;
        --device)        shift ; _device "${1}" ; shift ;;
        --random-device) shift ; _device "${CURRENT_DEVICE}" ;;
        --) shift ; CURRENT_OPTS= ;;
        *) CURRENT_OPTS="${CURRENT_OPTS} ${1}" ; shift ;;
    esac
done

exit 0
