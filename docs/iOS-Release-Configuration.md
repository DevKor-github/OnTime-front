# iOS Release Configuration

Release and archive builds must provide the same Dart define values that debug builds use for native iOS plist substitution.

## Required Dart Defines

- `GOOGLE_RESERVED_CLIENT_ID_IOS`: reversed iOS client ID used by Google Sign-In as the callback URL scheme in `ios/Runner/Info.plist`.
- `REST_API_URL`: production REST API base URL. Release builds must use an `https://` URL.

## Local Release Build

Run release builds with the required define:

```sh
flutter build ios --release \
  --dart-define=GOOGLE_RESERVED_CLIENT_ID_IOS=<reversed-ios-client-id> \
  --dart-define=REST_API_URL=https://api.ontime.devkor.club
```

For Xcode archives, add the same define to the Flutter build invocation or the CI step that prepares the archive.

## How Validation Works

The shared Runner scheme decodes Flutter `DART_DEFINES` into `ios/Flutter/Dart-Defines.xcconfig` before the build. `ios/Flutter/Release.xcconfig` includes that generated file so `$(GOOGLE_RESERVED_CLIENT_ID_IOS)` resolves in the built `Info.plist`.

Release builds fail clearly when a required define is missing or when `REST_API_URL` is not HTTPS. A release-only Xcode build phase also checks the built `Info.plist` and fails if the Google Sign-In URL scheme was not written into `CFBundleURLTypes`, or if the release plist enables arbitrary ATS loads.

Debug builds use `ios/Runner/Info-Debug.plist`, which keeps `NSAllowsArbitraryLoads` for the current HTTP debug API. Profile and Release builds use `ios/Runner/Info.plist`, which must remain production-strict.
