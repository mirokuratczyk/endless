platform :ios, "8.0"

# Disable sending stats
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target "Psiphon Browser" do 
	pod "DTFoundation"
	pod "OrderedDictionary"
	pod "MarqueeLabel"

	pod "InAppSettingsKit", :git => "https://github.com/Psiphon-Inc/InAppSettingsKit.git", :commit => '598c498'
	#pod "InAppSettingsKit", :path => "../InAppSettingsKit"
	pod 'PsiphonClientCommonLibrary', :git => "https://github.com/Psiphon-Inc/psiphon-ios-client-common-library.git", :commit => '0fd8d41'
	#pod 'PsiphonClientCommonLibrary', :path => "../psiphon-ios-client-common-library/"
	pod 'OCSPCache', :git => "https://github.com/Psiphon-Labs/OCSPCache.git", :commit => '9d7820e'
	#pod 'OCSPCache', :path => "../OCSPCache/"
end

target "Psiphon Browser Tests" do
	pod "OCMock"
end
