#!/bin/bash

set -e

STRINGS_DIR="Endless/en.lproj"
TEMP_DIR="${STRINGS_DIR}.temp"

rm -rf ${TEMP_DIR}
mkdir ${TEMP_DIR}

# Go through all source files, extracting localizable strings into appropriate
# `x.strings` files in a temp directory.
find . -name "*.m" -o -name "*.h" -o -name "*.swift" | xargs genstrings -o ${TEMP_DIR}

# Go through the `x.strings` files, converting from UTF-16 to UTF-8 and moving
# them into their proper location.
find ${TEMP_DIR} -name "*.strings"|while read fname; do
  bname=$(basename ${fname})
  echo "${bname} ${fname}"
  iconv -c -f UTF-16 -t UTF-8 ${fname} > ${STRINGS_DIR}/${bname}
done

rm -rf ${TEMP_DIR}
