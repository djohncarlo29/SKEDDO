# SKEDDO

## Overview

A Flutter/Dart mobile app called SKEDDO.

## Stack

- **Language**: Dart
- **Framework**: Flutter 3.35.7 (Dart 3.9.2)
- **UI style**: CupertinoApp (iOS-native widgets)

## App location

`artifacts/smart-scheduler/`

## Installed packages

- `cupertino_icons` — iOS-style icon set (companion to CupertinoApp)
- `flutter_sficon` — Apple SF Symbols icon rendering
- `http` — HTTP client (used by event extraction and speech services)
- `flutter_svg` — SVG rendering (used for custom icon assets)

## Text selection behavior

- All text fields use `CupertinoTextField` throughout the app. The cursor, selection handles, highlight colour, and copy/paste callout are all Flutter/Impeller-rendered and look identical on iOS and Android.

## Key commands

- `FLUTTER=/home/runner/workspace/.cache/flutter-3.35.7/bin/flutter; cd artifacts/smart-scheduler && "$FLUTTER" pub get` — install/update Dart dependencies using the pinned Flutter 3.35.7 toolchain
- `FLUTTER=/home/runner/workspace/.cache/flutter-3.35.7/bin/flutter; cd artifacts/smart-scheduler && "$FLUTTER" run -d web-server --web-port 24355 --web-hostname 0.0.0.0` — run dev server
- `FLUTTER=/home/runner/workspace/.cache/flutter-3.35.7/bin/flutter; cd artifacts/smart-scheduler && "$FLUTTER" build web` — production build
- `./build-apk.sh` — builds a signed Android release APK and copies it to `SKEDDO.apk` at the project root

## User preferences

- Do **not** trigger APK builds automatically after changes. Only build the APK when explicitly asked.
