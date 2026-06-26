# iOS TestFlight 1.0.0 Handoff

## Status

- `release/1.0.0` was fast-forwarded to the current `main` candidate.
- Android closed testing already has `1.0.0 (53)` from workflow run `28080538591` on `hotfix/remove-full-screen-intent`.
- The iOS bundle identifier is confirmed as `club.devkor.ontime.ios`.
- `docs/Release-Checklist.md` was corrected to use `club.devkor.ontime.ios`.
- `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, and `flutter test` passed locally.
- iOS archive succeeded at `build/ios/archive/Runner.xcarchive`.

## Blocker

`flutter build ipa` could not export an App Store IPA because local Xcode has no Apple account configured and no `iOS Distribution` signing certificate or provisioning profile for `club.devkor.ontime.ios`.

Observed export errors:

```text
error: exportArchive No Accounts
error: exportArchive No signing certificate "iOS Distribution" found
error: exportArchive No profiles for 'club.devkor.ontime.ios' were found
```

## Next Steps

1. Sign in to Xcode with an Apple Developer account that belongs to team `FV4XWCGPRZ`.
2. Ensure the App Store Connect app and bundle identifier `club.devkor.ontime.ios` exist.
3. Let Xcode automatic signing create or download an App Store provisioning profile, or install the team's distribution certificate/profile manually.
4. Re-run:

```sh
flutter build ipa --release \
  --dart-define=ENV=staging \
  --dart-define=GOOGLE_RESERVED_CLIENT_ID_IOS=$(plutil -extract REVERSED_CLIENT_ID raw ios/GoogleService-Info.plist) \
  --dart-define=REST_API_URL=https://ontime-back.duckdns.org
```

5. Upload the exported IPA to TestFlight through Xcode Organizer or Transporter.
6. If iOS TestFlight becomes the shared QA candidate, upload Android closed testing again from the same `release/1.0.0` branch with Android `versionCode` `54` or higher.
