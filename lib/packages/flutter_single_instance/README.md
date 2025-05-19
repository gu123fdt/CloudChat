# Flutter Single Instance

A simple way to check if your application is already running.

| Platform | Support |
| -------- | ------- |
| Android  | ⚠️      |
| iOS      | ⚠️      |
| Web      | ⚠️      |
| macOS    | ✅      |
| Windows  | ✅      |
| Linux    | ✅      |

✅ - Confirmed working. <br/>
⚠️ - Always reports as first instance.

## Installation

Add `flutter_single_instance` as a dependency in your `pubspec.yaml` file.

```yaml
flutter pub add flutter_single_instance
```

### MacOS

Disable sandboxing and enable networking in `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` files.

```xml
<key>com.apple.security.app-sandbox</key>
<false/>

<key>com.apple.security.network.server</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>
```

- `com.apple.security.app-sandbox`: Set to false to allow access to the filesystem.
- `com.apple.security.network.server`: Set to true to allow the app to act as a server and listen for incoming focus requests.
- `com.apple.security.network.client`: Set to true to allow the app to act as a client and send focus requests to the server (i.e. the main instance).

## Usage

A simple usage example:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  if (await FlutterSingleInstance().isFirstInstance()) {
    runApp(const MyApp());
  } else {
    print("App is already running");

    final err = await FlutterSingleInstance().focus();

    if (err != null) {
      print("Error focusing running instance: $err");
    }

    exit(0);
  }
}
```

## Web and other unsupported platforms

You can safely use this package in web and other unsupported platforms. It will always return `true` for `isFirstInstance` method.

## Limitations

- ~~Currently this package does not provide a way to bring the existing instance to the front. If you have any ideas on how to achieve this, please open an issue or a pull request.~~ This limitation has been resolved in version 1.2.0.
