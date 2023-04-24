#!/bin/sh -u
set -e

cd "$(dirname "$0")"

JUNGLE="../monkey.jungle"
MANIFEST="../manifest.xml"
DEVINFO="devices.csv"
GEN_DIR="generated"

rm -f "${JUNGLE}"

_jungle() {
    printf "$@" >> "${JUNGLE}"
}

_jungle "project.manifest = $(basename "${MANIFEST}")\n\n"

_generate_assets() {
    ICON_WIDTH=$(( ${4} * 15 / 100 ))
    ICON_HEIGHT=$(( ${5} * 15 / 100 ))
    FONT_WIDTH=$(( ${4} * 12 / 100 ))
    FONT_HEIGHT=$(( ${5} * 12 / 100 ))
    FONT_LINEHEIGHT=$(( ${FONT_HEIGHT} ))

    mkdir -p "${1}/drawables"
    echo "Generating drawables for ${6} with resolution ${4}x${5} into ${1}"
    echo " Copying xml files"
    cp -v "drawables/"*.xml "${1}/drawables/"

    echo " Generating launcher icon"
    for INPUT in $(grep -oE 'filename="[^"]*"' "drawables/"launcher_icon.xml | sed -e 's/filename="\([^"]*\)"/\1/') ; do
        echo "  Generating ${INPUT} > " convert "drawables/${INPUT}" -resize ${2}x${3} "${1}/drawables/${INPUT}"
        convert "drawables/${INPUT}" -resize ${2}x${3} "${1}/drawables/${INPUT}"
    done

    mkdir -p "${1}/fonts"
    echo "Generating fonts for ${6} with resolution ${4}x${5} into ${1}"
    echo " Copying xml files"
    cp -v "fonts/"*.xml "${1}/fonts/"

    echo " Generating fonts"
    for INPUT in "$(grep -F '<font id=' "fonts/"fonts.xml)" ; do
        FONT_ID=$(echo "${INPUT}" | grep -oE 'id="[^"]*"' | sed -e 's/id="\([^"]*\)"/\1/')
        FONT_FILENAME=$(echo "${INPUT}" | grep -oE 'filename="[^"]*"' | sed -e 's/filename="\([^"]*\)"/\1/')
        FONT_FILTER=$(echo "${INPUT}" | grep -oE 'filter="[^"]*"' | sed -e 's/filter="\([^"]*\)"/\1/')
        echo "  Generating font ${FONT_ID} from ${FONT_FILENAME} with filter ${FONT_FILTER}"
        mkdir -p "${1}/fonts/${FONT_ID}"
        cp -v "fonts/${FONT_FILENAME}" "${1}/fonts/"
        sed -i '' 's/{FONT_ID}/'${FONT_ID}'/g' "${1}/fonts/${FONT_FILENAME}"
        sed -i '' 's/{FONT_WIDTH}/'${FONT_WIDTH}'/g' "${1}/fonts/${FONT_FILENAME}"
        sed -i '' 's/{FONT_HEIGHT}/'${FONT_HEIGHT}'/g' "${1}/fonts/${FONT_FILENAME}"
        sed -i '' 's/{FONT_LINEHEIGHT}/'${FONT_LINEHEIGHT}'/g' "${1}/fonts/${FONT_FILENAME}"
        for FILTER in $(echo ${FONT_FILTER} | grep -Eo '.') ; do
            echo "   Generating ${FILTER} for font ${FONT_ID} from ${FONT_FILENAME} with filter ${FONT_FILTER}"
            sed -i '' 's/{FONT_X'${FILTER}'}/'$(( (${FONT_WIDTH} + 1) * ${FILTER} ))'/g' "${1}/fonts/${FONT_FILENAME}"
            convert "fonts/${FONT_ID}/${FILTER}.png" \
                -colorspace Gray -ordered-dither h4x4a \
                -resize ${FONT_WIDTH}x${FONT_HEIGHT} \
                -gravity center -extent ${FONT_WIDTH}x${FONT_HEIGHT} \
                -alpha off -negate \
                "${1}/fonts/${FONT_ID}/${FILTER}.png"
        done
        rm -f "${1}/fonts/${FONT_ID}/sprites.png"
        convert "${1}/fonts/${FONT_ID}/*.png" \
            -background red -splice 1x0+0+0 \
            +append -chop 1x0+0+0 "${1}/fonts/${FONT_ID}/sprites.png"
    done
}

_generate_resources() {
    mkdir -pv "${GEN_DIR}/$1"
    _jungle "$1.resourcePath = \$(base.resourcePath);$(basename "$(pwd)")/${GEN_DIR}/$1\n"
    LWLHWWHHID="$(grep -F ";$1" "${DEVINFO}" | tr ';' ' ')"
    _generate_assets "${GEN_DIR}/$1" ${LWLHWWHHID}
}

SHAPES="$(sed -ne "s/^.*;\([^;]*\)$/\1/p" "${DEVINFO}" | grep -E '^(base|round|semiround|rectangle|semioctagon)')"
for SHAPE in ${SHAPES} ; do
    _generate_resources ${SHAPE}
done

DEVICES="$(sed -ne "s/^.*iq:product.*id=\"\([^\"]*\).*$/\1/p" "${MANIFEST}")"
for DEVICE in ${DEVICES} ; do
    _generate_resources ${DEVICE}
done

LINES="$(grep -oE "^[^ ]*" "${JUNGLE}")"
for LINE in ${LINES} ; do
    sed -e "s/\(${LINE}.*\)\$(${LINE});/\1resources;/g" "${JUNGLE}" > "${JUNGLE}tmp"
    mv -f "${JUNGLE}tmp" "${JUNGLE}"
done

exit 0
