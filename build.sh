#!/bin/bash
set -u -e

BASE_DIR=$(cd "$(dirname "$0")" ; pwd -P)

usage () {
    echo " Usage: ${0}:"
    echo ""
    echo "-c: clean"
    echo "-a: archive (generates xcarchive)"
    echo "-s: sign (generates ipa)"
    echo ""
    exit 1
}

setup_env () {
    cd ${BASE_DIR}

    PSIPHON_BROWSER_WORKSPACE="${BASE_DIR}"

    # Location of build output
    BUILD_DIR="${PSIPHON_BROWSER_WORKSPACE}/build"

    # Clean previous output
    rm -rf "${BUILD_DIR}"
}

archive () {
    xcodebuild -workspace Psiphon\ Browser.xcworkspace  -scheme Psiphon\ Browser  -sdk iphoneos -configuration AppStoreDistribution archive -archivePath $PWD/build/PsiphonBrowser.xcarchive
}

clean () {
    xcodebuild clean -workspace Psiphon\ Browser.xcworkspace -scheme Psiphon\ Browser
}

sign () {
    # Generate the IPA for upload to iTunes Connect
    xcodebuild -exportArchive -archivePath $PWD/build/PsiphonBrowser.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build
}

# If no arguments are set
if [ $# -ne 1 ]; then
    usage
fi

# Unset flags just to be sure
unset FLAG_CLEAN
unset FLAG_ARCHIVE
unset FLAG_SIGN

while getopts ":acs" opt; do
case $opt in
    c)
      FLAG_CLEAN=1
      ;;
    a)
      FLAG_ARCHIVE=1
      ;;
    s)
      FLAG_SIGN=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

setup_env

if [ ! -z ${FLAG_CLEAN+x} ];
then
    echo "Cleaning..."
    clean
fi

if [ ! -z ${FLAG_ARCHIVE+x} ];
then
    echo "Archiving..."
    archive
fi

if [ ! -z ${FLAG_SIGN+x} ];
then
    echo "Signing archive..."
    sign
fi
