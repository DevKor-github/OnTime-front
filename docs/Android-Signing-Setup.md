# Android Signing Setup

Use this guide when preparing OnTime for Google Play release builds.

## Key Concepts

- Google Play releases should use Play App Signing.
- The local team keeps an upload key and uses it to sign app bundles before
  uploading them to Play Console.
- Google Play uses the upload key to verify the upload, then signs distributed
  APKs with the app signing key.
- Do not commit keystores, passwords, `android/key.properties`, or generated
  release artifacts.

## Create an Upload Key

Create and store the keystore somewhere outside the repository:

```sh
mkdir -p ~/secure

keytool -genkeypair -v \
  -keystore ~/secure/ontime-upload.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias ontime
```

Save the keystore file and passwords in the team password manager or secret
manager. Losing the upload key requires a Play Console upload-key reset.

## Configure Local Release Signing

Create `android/key.properties` locally:

```properties
storeFile=/absolute/path/to/ontime-upload.jks
storePassword=<keystore-password>
keyAlias=ontime
keyPassword=<key-password>
```

`android/key.properties` is ignored by git and must stay local.

Alternatively, set environment variables:

```sh
export ONTIME_ANDROID_KEYSTORE_PATH=/absolute/path/to/ontime-upload.jks
export ONTIME_ANDROID_KEYSTORE_PASSWORD='<keystore-password>'
export ONTIME_ANDROID_KEY_ALIAS=ontime
export ONTIME_ANDROID_KEY_PASSWORD='<key-password>'
```

## Build a Signed Release

Google Play prefers Android App Bundles:

```sh
flutter build appbundle --release
```

For APK validation outside Play:

```sh
flutter build apk --release
```

The Gradle config intentionally fails release builds when signing secrets are
missing. Debug builds do not require release signing secrets.

## First Play Console Release

1. Create or open the app in Google Play Console.
2. Create a release on an internal testing track first.
3. Configure Play App Signing when prompted.
4. Use Google-generated app signing key unless the team needs to share the same
   signing key across multiple stores or related apps.
5. Upload the `.aab` from `build/app/outputs/bundle/release/`.
6. After Play App Signing is active, continue signing future uploads with the
   same local upload key.

## Existing Play Console App

- If the app already has an upload key, use that existing key.
- If the upload key is lost but Play App Signing is enabled, request an upload
  key reset in Play Console.
- If Play App Signing is not enabled and the app signing key is lost, the app
  generally cannot be updated under the same package name.

## Verification

Run these checks before handing a release build to QA or Play Console:

```sh
flutter analyze
flutter test
flutter build appbundle --release
```

Confirm that `pubspec.yaml` has the intended `version` and that the build number
is greater than every previous Play Console upload for `club.devkor.ontime`.
