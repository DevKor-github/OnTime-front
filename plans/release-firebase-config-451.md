# Release Firebase Config Plan (#451)

## Scope

- Define the Android release Firebase config source for `google-services.json`.
- Keep the real Firebase config out of git by documenting the CI secret decode path.
- Validate that the release config contains an Android client for package `club.devkor.ontime`.
- Document that release auth SHA-1/SHA-256 fingerprints are added after signing decisions are finalized.

## Files Likely Touched

- `android/app/build.gradle`
- `docs/Android-Release-Configuration.md`
- `plans/release-firebase-config-451.md`

## Implementation Approach

1. Reuse the existing release config locations, preferring `android/app/src/release/google-services.json`.
2. Parse the selected release `google-services.json` with Gradle/Groovy JSON support when a release build is requested.
3. Fail release builds clearly when the config is missing or when no Android client has package name `club.devkor.ontime`.
4. Add a focused Gradle validation task so CI or developers can validate the release Firebase config before a full release build.
5. Update release docs with the validation behavior, CI secret source, and the remaining fingerprint handoff to the Play signing issue.

## Verification

- `cd android && gradle :app:validateAndroidGoogleServices` with a temporary matching `android/app/src/release/google-services.json`.
- `cd android && gradle :app:validateAndroidGoogleServices` with a temporary mismatched package to confirm failure.
- `flutter analyze` if local Flutter/Android tooling is available and the change does not require secrets.

## Blockers

- The actual production `ANDROID_GOOGLE_SERVICES_JSON_B64` secret cannot be verified without repository/environment secret access.
- Release auth SHA-1/SHA-256 fingerprints cannot be added until signing and Play App Signing decisions are finalized in #450/#454.

## Explicitly Left Out

- Creating or committing a real `google-services.json`.
- Modifying release signing ownership, keystore setup, or versioning.
- Building/uploading the signed AAB or performing Play Console verification.
