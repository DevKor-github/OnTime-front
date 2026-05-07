# Android Release Configuration

Android release builds must include the production Firebase client config so Firebase Core and Firebase Messaging initialize consistently.

## Required CI Secret

- `ANDROID_GOOGLE_SERVICES_JSON_B64`: base64-encoded contents of the production Android `google-services.json` for Firebase project `ontime-c63f1`.

The release verification workflow decodes this secret to `android/app/src/release/google-services.json` before running the Android release build. Generated `google-services.json` files are ignored and must not be committed.

## Local Release Build

Create the release source-set config before building:

```sh
mkdir -p android/app/src/release
base64 --decode android-google-services.json.b64 > android/app/src/release/google-services.json
flutter build appbundle --release --dart-define=REST_API_URL=<api-url>
```

On macOS, use `base64 -D` instead of `base64 --decode`.

Debug/local builds may run without Android Firebase config. Release builds fail clearly if `android/app/src/release/google-services.json`, `android/app/google-services.json`, or `android/app/src/google-services.json` is missing.

## Verification

Use the `Android Release Verification` GitHub Actions workflow to confirm CI can reproduce the release build with the configured secret. For production readiness, also install a real Android release build and verify Firebase initializes and FCM token registration reaches the backend.
