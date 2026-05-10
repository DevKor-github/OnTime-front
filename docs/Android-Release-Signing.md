# Android Release Signing

Android release builds must be signed with the production release key. Debug signing is only for debug and profile builds.

## Ownership and Storage

The Android release owner is the person or team role with Google Play release
responsibility for `club.devkor.ontime`. That owner is responsible for creating
or confirming the upload keystore, keeping access limited to release maintainers,
and rotating or resetting the upload key if access is lost.

Store the upload keystore and passwords outside the repository in the team
password manager or CI secret manager. Record the current owner and recovery
notes in that secure system, not in git. Do not send keystores or passwords in
issue comments, pull requests, chat logs, screenshots, or build artifacts.

## Required Signing Inputs

Release builds require all of these values:

- `storeFile`: path to the release keystore file
- `storePassword`: keystore password
- `keyAlias`: release key alias
- `keyPassword`: release key password

The Gradle build reads these values from `android/key.properties` first. If that file is absent or a value is missing, it falls back to environment variables:

- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

For compatibility with existing release metadata work, Gradle also accepts the legacy `ONTIME_ANDROID_KEYSTORE_PATH`, `ONTIME_ANDROID_KEYSTORE_PASSWORD`, `ONTIME_ANDROID_KEY_ALIAS`, and `ONTIME_ANDROID_KEY_PASSWORD` variable names.

## Local Release Build

Create `android/key.properties` on your machine:

```properties
storeFile=/absolute/path/to/release-keystore.jks
storePassword=<keystore-password>
keyAlias=<release-key-alias>
keyPassword=<release-key-password>
```

Then build the release artifact:

```sh
flutter build appbundle --release
```

`android/key.properties`, `*.jks`, and `*.keystore` files are ignored by git. Do not commit keystores or signing passwords.

## CI Release Build

CI should materialize the release keystore from a secure secret store, then provide the required environment variables to the Flutter build step:

```sh
export ANDROID_KEYSTORE_PATH=/secure/path/release-keystore.jks
export ANDROID_KEYSTORE_PASSWORD=<keystore-password>
export ANDROID_KEY_ALIAS=<release-key-alias>
export ANDROID_KEY_PASSWORD=<release-key-password>

flutter build appbundle --release \
  --build-name=<version name from pubspec.yaml> \
  --build-number=<monotonic Android versionCode>
```

The GitHub Actions Play deploy workflow expects the keystore bytes in
`ANDROID_UPLOAD_KEYSTORE_B64`, decodes them to a temporary runner path, and then
exports `ANDROID_KEYSTORE_PATH`. The keystore file should never be written into
the repository checkout in CI.

## How Validation Works

Gradle checks release signing inputs only when a release task is requested. Debug and profile builds do not require release signing credentials.

Release builds fail before packaging if any required value is absent or if the keystore file path does not exist. The error message lists the missing inputs so local and CI setup failures are explicit.

Expected setup failures look like:

```text
Android release signing is required for release builds. Missing: storeFile, ANDROID_KEYSTORE_PATH, or ONTIME_ANDROID_KEYSTORE_PATH, ...
```
