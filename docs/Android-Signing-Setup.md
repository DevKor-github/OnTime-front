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

## Ownership and Secret Storage

The Android release owner for `club.devkor.ontime` owns the upload keystore
process. This role is responsible for:

- creating or confirming the current upload keystore;
- storing the keystore file and passwords in the team password manager or CI
  secret manager;
- limiting access to release maintainers;
- documenting recovery notes in the secure storage record;
- rotating or requesting a Play Console upload-key reset if the upload key is
  lost or exposed.

Never store keystore files or passwords in git, issue comments, pull requests,
chat logs, screenshots, or build artifacts.

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
export ANDROID_KEYSTORE_PATH=/absolute/path/to/ontime-upload.jks
export ANDROID_KEYSTORE_PASSWORD='<keystore-password>'
export ANDROID_KEY_ALIAS=ontime
export ANDROID_KEY_PASSWORD='<key-password>'
```

The Gradle build also accepts the legacy `ONTIME_ANDROID_KEYSTORE_PATH`,
`ONTIME_ANDROID_KEYSTORE_PASSWORD`, `ONTIME_ANDROID_KEY_ALIAS`, and
`ONTIME_ANDROID_KEY_PASSWORD` variable names for compatibility.

## Configure CI Release Signing

For GitHub Actions deploys, base64-encode the upload keystore and store it as
the `ANDROID_UPLOAD_KEYSTORE_B64` secret in the protected `release`
environment:

```sh
base64 -i ~/secure/ontime-upload.jks | pbcopy
```

On Linux, use:

```sh
base64 -w 0 ~/secure/ontime-upload.jks
```

The deploy workflow decodes this secret into `$RUNNER_TEMP/ontime-upload.jks`
and exports `ANDROID_KEYSTORE_PATH` to that temporary file. Do not create
`android/key.properties` in CI.

The protected environment must also provide:

- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Build a Signed Release

Google Play prefers Android App Bundles:

```sh
flutter build appbundle --release \
  --build-name=<version name from pubspec.yaml> \
  --build-number=<monotonic Android versionCode>
```

For APK validation outside Play:

```sh
flutter build apk --release
```

The Gradle config intentionally fails release builds when signing secrets are
missing. The failure lists missing local or CI inputs, including
`storeFile`/`ANDROID_KEYSTORE_PATH`, `storePassword`/`ANDROID_KEYSTORE_PASSWORD`,
`keyAlias`/`ANDROID_KEY_ALIAS`, and `keyPassword`/`ANDROID_KEY_PASSWORD`. Debug
builds do not require release signing secrets.

## First Play Console Release

1. Create or open the app in Google Play Console.
2. Create a release on an internal testing track first.
3. Configure Play App Signing when prompted.
4. Use Google-generated app signing key unless the team needs to share the same
   signing key across multiple stores or related apps.
5. Upload the `.aab` from `build/app/outputs/bundle/release/`.
6. After Play App Signing is active, continue signing future uploads with the
   same local upload key.
7. Record the Play app signing and upload key SHA-1/SHA-256 fingerprints using
   `docs/Android-Play-Signing-Fingerprints.md`.

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
flutter build appbundle --release \
  --build-name=<version name from pubspec.yaml> \
  --build-number=<monotonic Android versionCode>
```

Confirm that `pubspec.yaml` has the intended public version name. In GitHub
Actions deploys, Android `versionCode` comes from `github.run_number`; for any
manual Play upload, provide a build number greater than every previous Play
Console upload for `club.devkor.ontime`.
