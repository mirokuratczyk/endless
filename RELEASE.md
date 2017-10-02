# Releasing Psiphon Browser for iOS

### Prerequisites

* xcode `xcode-select --install`

* [git](https://git-scm.com/download/mac)

* [Cocoapods](https://cocoapods.org/)

* [Apple signing identity with proper distribution profile](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/ConfiguringYourApp/ConfiguringYourApp.html#//apple_ref/doc/uid/TP40012582-CH28-SW1)

### Create app *.ipa package steps

* clone the master repo `git clone https://github.com/Psiphon-Inc/endless.git`.

* run `pod install` in the repo root directory, get a copy of psiphon config JSON and embedded servers JSON files and put them under `<repo>/Endless/psiphon_config` and `<repo>/Endless/embedded_server_entries` respectively. Open `Psiphon Browser.xcworkspace` in Xcode and make sure the project builds.

* Increment CFBundleVersion number in the Endless/Info.plist and commit the change. Create a git tag with the same number `git tag "beta.<new_bundle_version_number>"` and push the commit and the tag to remote.

* Rename `exportOptions.plist.stub` to `exportOptions.plist` and edit `provisioningProfiles` section if provisioning profile name is different from the one in the stub.

* Run the following script in the repo root directory
```
xcodebuild clean -workspace Psiphon\ Browser.xcworkspace -scheme Psiphon\ Browser
xcodebuild -workspace Psiphon\ Browser.xcworkspace  -scheme Psiphon\ Browser  -sdk iphoneos -configuration AppStoreDistribution archive -archivePath $PWD/build/PsiphonBrowser.xcarchive
xcodebuild -exportArchive -archivePath $PWD/build/PsiphonBrowser.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build
```

* The result *.ipa will be located in `<repo>/build` directory


### Upload to iTunes Connect

* Use Application Loader (Xcode -> Open Developer Tool -> Application Loader) to upload the *.ipa to the App Store.

* Use iTunes Connect web interface to set up new TestFlight tests using the newly uploaded build, submit for App/Beta review, etc.
