# iOS Release Configuration

OnTime's Android and iOS product builds are local-only. Release builds do not
accept API endpoints, Firebase configuration, remote-authentication client IDs,
or environment-specific Dart defines.

## Local Release Build

Use `pubspec.yaml` as the source of the public version and build number, then
build the signed App Store archive and IPA:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_local_only_boundary.dart
flutter analyze
flutter test
flutter build ipa --release --export-method app-store
```

The bundle identifier is `club.devkor.ontime.ios`, and automatic signing uses
the Apple Developer team configured in the Runner target. Never commit signing
certificates, provisioning profiles, App Store Connect credentials, generated
Pods, or built archives.

## Release Verification

- Inspect the archived entitlements and merged `Info.plist` before upload.
- Confirm that the product contains no Google/Firebase URL scheme, remote
  notification background mode, or push/authentication entitlement.
- Confirm the app starts in airplane mode from a clean installation and can
  complete onboarding, schedule management, local delivery, backup, restore,
  and reset without contacting a server.
- Upload the IPA to App Store Connect and verify that the processed build has
  the same version, build number, bundle identifier, and commit SHA.
