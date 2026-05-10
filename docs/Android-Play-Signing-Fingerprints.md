# Android Play Signing Fingerprints

Use this checklist to complete issue #454 after Play App Signing and the
upload key decision are finalized for `club.devkor.ontime`.

Do not paste keystores, passwords, service-account JSON, or raw
`google-services.json` contents into issues, pull requests, chat, or screenshots.
Fingerprints are safe to record, but the evidence should still avoid exposing
unrelated Play Console or Firebase project data.

## Preconditions

- #450 is complete: the upload keystore owner, storage process, and local or CI
  signing inputs are known.
- #451 is complete: the release Firebase config source is known and validates
  package `club.devkor.ontime`.
- Play App Signing is active or the release owner has confirmed the first-upload
  setup path in Play Console.
- The release owner can access Google Play Console, Firebase console, and every
  auth provider console used by Android release sign-in.

## Values To Record

Record the following in the secure release record or issue status note:

| Field | Value |
| --- | --- |
| Package name | `club.devkor.ontime` |
| Play App Signing status | Pending / Active |
| Play app signing certificate SHA-1 |  |
| Play app signing certificate SHA-256 |  |
| Upload key certificate SHA-1 |  |
| Upload key certificate SHA-256 |  |
| Firebase project | `ontime-c63f1` |
| Firebase Android app package | `club.devkor.ontime` |
| Firebase fingerprints updated by |  |
| Firebase fingerprints updated at |  |
| Google Sign-In Android OAuth client checked | Yes / No / Not used |
| Kakao Android key hash checked | Yes / No / Not used |
| Backend allowlist checked, if any | Yes / No / Not used |
| Updated release `google-services.json` secret required | Yes / No |

## Collect Play Console Fingerprints

1. Open Google Play Console for `club.devkor.ontime`.
2. Go to **Test and release** > **Setup** > **App signing**. The same page is
   also linked from **Test and release** > **App integrity**.
3. Confirm whether Play App Signing is active.
4. Copy the app signing key certificate SHA-1 and SHA-256 fingerprints.
5. Copy the upload key certificate SHA-1 and SHA-256 fingerprints.
6. Confirm the upload key shown in Play Console matches the keystore used by
   local release signing or the `ANDROID_UPLOAD_KEYSTORE_B64` CI secret.

If the first upload has not happened yet, stop here and record that #454 is
waiting on the initial signed AAB upload and Play App Signing enrollment.

## Cross-Check The Upload Keystore

The release owner can verify the local upload key without exposing the keystore:

```sh
keytool -list -v \
  -keystore /absolute/path/to/ontime-upload.jks \
  -alias <upload-key-alias>
```

Compare the SHA-1 and SHA-256 output with the Play Console upload key
certificate. If they differ, do not upload a release until the release owner
confirms whether Play Console needs an upload-key reset or CI/local signing is
using the wrong keystore.

## Update Firebase

1. Open Firebase console for project `ontime-c63f1`.
2. Open **Project settings** > **General** > Android app
   `club.devkor.ontime`.
3. Add the Play app signing certificate SHA-1 and SHA-256 fingerprints.
4. Add the upload key certificate SHA-1 and SHA-256 fingerprints if the team
   uses locally installed release APKs, direct App Distribution builds, or any
   provider flow that validates the upload-key-signed artifact before Play
   re-signing.
5. Check whether Firebase generated an updated `google-services.json`.
6. If the file changed, update only the secure
   `ANDROID_GOOGLE_SERVICES_JSON_B64` secret and validate the decoded file with:

```sh
cd android
gradle :app:validateAndroidGoogleServices
```

Do not commit `google-services.json`.

## Update Auth Provider Consoles

Check every Android release auth provider used by the app:

- Google Sign-In: confirm the Android OAuth client uses package
  `club.devkor.ontime` and the Play app signing SHA-1. If separate debug,
  upload-key, or internal-testing clients are required, record why.
- Kakao: confirm the Android platform entry uses package `club.devkor.ontime`
  and the release key hash derived from the finalized signing certificate.
- Backend OAuth settings: if the backend validates Android package or
  certificate fingerprints, confirm its allowlist matches the finalized release
  values.

## Completion Evidence

Paste a status note using this template:

```md
## #454 Play Signing Fingerprint Status

- Play App Signing status:
- Package: `club.devkor.ontime`
- Play app signing SHA-1:
- Play app signing SHA-256:
- Upload key SHA-1:
- Upload key SHA-256:
- Firebase Android app updated: yes/no
- `ANDROID_GOOGLE_SERVICES_JSON_B64` rotated: yes/no/not needed
- Google Sign-In checked: yes/no/not used
- Kakao checked: yes/no/not used
- Backend allowlist checked: yes/no/not used
- Verified by:
- Verified date:
- Remaining blockers:
```

Issue #454 is complete only when the fingerprints are recorded, Firebase has
the required release fingerprints, and the provider settings are checked against
the release package and final certificate values.

## References

- Google Play Console Help: <https://support.google.com/googleplay/android-developer/answer/9842756>
- Firebase Management API SHA certificates: <https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.androidApps.sha>
- Kakao Developers app settings: <https://developers.kakao.com/docs/en/app-setting/app>
