#!/usr/bin/env bash
git apply ./scripts/enable-android-google-services.patch
CLOUDCHAT_ORIG_GROUP="im.cloudchat"
CLOUDCHAT_ORIG_TEAM="4NXF6Z997G"
#CLOUDCHAT_NEW_GROUP="com.example.cloudchat"
#CLOUDCHAT_NEW_TEAM="ABCDE12345"

# In some cases (ie: running beta XCode releases) some pods haven't updated their minimum version
# but XCode will reject the package for using too old of a minimum version. 
# This will fix that, but. Well. Use at your own risk.
# export I_PROMISE_IM_REALLY_SMART=1

# If you want to automatically install the app
# export CLOUDCHAT_INSTALL_IPA=1

### Rotate IDs ###
[ -n "${CLOUDCHAT_NEW_GROUP}" ] && {
	# App group IDs
	sed -i "" "s/group.${CLOUDCHAT_ORIG_GROUP}.app/group.${CLOUDCHAT_NEW_GROUP}.app/g" "macos/Runner/Runner.entitlements"
	sed -i "" "s/group.${CLOUDCHAT_ORIG_GROUP}.app/group.${CLOUDCHAT_NEW_GROUP}.app/g" "macos/Runner.xcodeproj/project.pbxproj"
	# Bundle identifiers
	sed -i "" "s/${CLOUDCHAT_ORIG_GROUP}.app/${CLOUDCHAT_NEW_GROUP}.app/g" "macos/Runner.xcodeproj/project.pbxproj"
}

[ -n "${CLOUDCHAT_NEW_TEAM}" ] && {
	# Code signing team
	sed -i "" "s/${CLOUDCHAT_ORIG_TEAM}/${CLOUDCHAT_NEW_TEAM}/g" "macos/Runner.xcodeproj/project.pbxproj"
}

### Make release build ###
flutter build macos --release

cp /usr/local/Cellar/libolm/**/lib/libolm.3.dylib build/macos/Build/Products/Release/CloudChat.app/Contents/Frameworks/libolm.3.dylib

echo "Build build/macos/Build/Products/Release/CloudChat.app"
