# iOS release 1.0.2 build 54 handoff

Date: 2026-06-29 KST
Branch: `release/1.0.2-build-54`

## Completed

- Pulled latest `origin/main` and created/pushed `release/1.0.2-build-54`.
- Set `pubspec.yaml` to `version: 1.0.2+1`.
- Android closed testing deploy completed successfully with versionCode `54`.
- iOS no-codesign release build completed:
  - `flutter build ios --release --no-codesign --build-name=1.0.2 --build-number=54 --dart-define=ENV=staging --dart-define=REST_API_URL=https://ontime-back.duckdns.org --dart-define=GOOGLE_RESERVED_CLIENT_ID_IOS=com.googleusercontent.apps.456571312261-e0g33a9qnct35j1uud89dmfcnv9lffeq`
  - Output: `build/ios/iphoneos/Runner.app`
- Verified built iOS app metadata:
  - `CFBundleShortVersionString`: `1.0.2`
  - `CFBundleVersion`: `54`
  - `CFBundleIdentifier`: `club.devkor.ontime.ios`
  - Google reversed client URL scheme present.
- Xcode archive completed:
  - `build/ios/archive/Runner.xcarchive`

## Blocker

`flutter build ipa --release --build-name=1.0.2 --build-number=54 --export-method app-store ...` failed during IPA export:

```text
error: exportArchive No Accounts
error: exportArchive No signing certificate "iOS Distribution" found
```

Local keychain currently has only:

```text
Apple Development: Ejun Park (9NWQBWJ4DF)
```

The repository also has no iOS/TestFlight GitHub Actions workflow, no Fastlane setup, and the visible GitHub environment secrets for `staging` only cover Android/Google Play release credentials.

## Next steps

1. Add an Apple Distribution certificate and App Store provisioning profile for `club.devkor.ontime.ios`, or configure Xcode/App Store Connect account access for automatic signing.
2. Re-run the IPA build:

```sh
flutter build ipa --release \
  --build-name=1.0.2 \
  --build-number=54 \
  --export-method app-store \
  --dart-define=ENV=staging \
  --dart-define=REST_API_URL=https://ontime-back.duckdns.org \
  --dart-define=GOOGLE_RESERVED_CLIENT_ID_IOS=com.googleusercontent.apps.456571312261-e0g33a9qnct35j1uud89dmfcnv9lffeq
```

3. Upload the generated IPA to App Store Connect/TestFlight with Xcode Organizer or a configured App Store Connect API key workflow.
