# CloudChat AppImage

CloudChat is provided as AppImage too. To Download, visit cloudchat.im.

## Building

- Ensure you install `appimagetool`

```shell
flutter build linux

# copy binaries to appimage dir
cp -r build/linux/{x64,arm64}/release/bundle appimage/CloudChat.AppDir
cd appimage

# prepare AppImage files
cp CloudChat.desktop CloudChat.AppDir/
mkdir -p CloudChat.AppDir/usr/share/icons
cp ../assets/logo.svg CloudChat.AppDir/cloudchat.svg
cp AppRun CloudChat.AppDir

# build the AppImage
appimagetool CloudChat.AppDir
```
