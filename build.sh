#!/bin/bash
set -e -x
rm -rf build
xcodebuild clean -workspace Psiphon\ Browser.xcworkspace -scheme Psiphon\ Browser
xcodebuild -workspace Psiphon\ Browser.xcworkspace  -scheme Psiphon\ Browser  -sdk iphoneos -configuration AppStoreDistribution archive -archivePath $PWD/build/PsiphonBrowser.xcarchive
xcodebuild -exportArchive -archivePath $PWD/build/PsiphonBrowser.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build

