# Google Play Data Safety Worksheet

This worksheet advances release issue #441 under parent track #464. It is not a
final Google Play declaration and must not be pasted into Play Console until the
open prerequisites below are resolved.

## Status

Current status: externally blocked.

Blocking prerequisites:

| Input | Source issue | Status on 2026-05-10 | Why it blocks submission |
| --- | --- | --- | --- |
| Approved privacy policy text | #434 | Open, manual | Google Play requires a privacy policy and the Data safety answers must match it. |
| Backend deletion and retention truth | #439 | Open, manual/backend | Data deletion support, retention exceptions, and associated data deletion are server-side facts. |
| External account deletion request URL | #440 | Open, manual | Play requires an outside-app deletion path for apps with accounts. |
| Manifest permission audit | #442 | Closed | Evidence is available in `docs/Android-Manifest-Permissions.md`. |
| Final release SDK/provider set | #441 prerequisite | Pending owner confirmation | SDK data collection must match the shipped release build. |

Google's current guidance says developers are responsible for complete and
accurate declarations, including data handled by third-party SDKs, and should
review app permissions, APIs, SDK behavior, privacy policy, encryption, sharing,
and deletion practices before submitting the form:

- https://support.google.com/googleplay/android-developer/answer/10787469
- https://developers.google.com/android/guides/play-data-disclosure
- https://firebase.google.com/docs/android/play-data-disclosure

## Source Evidence Reviewed

Repo evidence reviewed for this worksheet:

- `pubspec.yaml`
- `lib/core/constants/endpoint.dart`
- `lib/data/data_sources/authentication_remote_data_source.dart`
- `lib/data/data_sources/schedule_remote_data_source.dart`
- `lib/data/data_sources/preparation_remote_data_source.dart`
- `lib/data/data_sources/alarm_remote_data_source.dart`
- `lib/data/data_sources/notification_remote_data_source.dart`
- `lib/data/data_sources/token_local_data_source.dart`
- `lib/data/repositories/user_repository_impl.dart`
- `lib/domain/entities/user_entity.dart`
- `lib/domain/entities/schedule_entity.dart`
- `lib/domain/entities/place_entity.dart`
- `lib/domain/entities/alarm_entities.dart`
- `docs/Android-Manifest-Permissions.md`
- `docs/Release-Checklist.md`

## Current App Data Flow Inventory

This table maps current source evidence to likely Google Play Data safety review
areas. Final categories, required or optional status, purposes, sharing, and
deletion support must be approved by the release owner.

| Data flow | Current source evidence | Likely form area | Current confidence |
| --- | --- | --- | --- |
| Account sign-up and sign-in | Normal auth sends email, password, and name to `/login` and `/sign-up`; user responses include id, email, name, spare time, note, score. | Personal info, account management, app functionality | Source-backed, backend retention pending |
| Google sign-in | Google auth requests `email` and `profile` scopes and sends an ID token to `/oauth2/google/login`. | Personal info and identifiers handled through Google sign-in | Source-backed, final provider set pending |
| Apple sign-in | Apple auth requests email and full name scopes and sends ID token, auth code, full name, and optional email to `/oauth2/apple/login`. | Personal info and identifiers handled through Apple sign-in | Source-backed, final provider set pending |
| Auth tokens | Access and refresh tokens are stored in `flutter_secure_storage` and sent as bearer authorization headers. | Security credential handling, not a Play user-facing data category by itself unless policy owner maps it | Source-backed, policy mapping pending |
| Schedules | Schedule create/update sends schedule id, place id, place name, schedule name, schedule time, move time, spare time, started/change flags, and schedule note. | App activity, user-generated content, possible location/place information | Source-backed, final category mapping pending |
| Preparation steps and spare time | Default and schedule preparation APIs send preparation ids, names, durations, ordering links, spare time, and note. | App activity or user-generated content | Source-backed, final category mapping pending |
| Feedback and deletion feedback | Feedback endpoints send generated feedback id and free-text message; deletion can include optional feedback. | App activity or user-generated content, depending on final policy wording | Source-backed, backend retention pending |
| Push notification registration | FCM token registration sends `firebaseToken` and app-generated `deviceId` to `/firebase-token`. | Device or other identifiers, app functionality | Source-backed, SDK disclosure pending |
| Alarm device registration | Current device registration sends app-generated device id, platform, app version, OS version, native alarm support, and alarm providers. | Device or other identifiers, app info and performance | Source-backed, backend retention pending |
| Alarm status reporting | Alarm status reports send device id, reconciliation timestamps, schedule window, coverage window, alarm provider, status, permission issue, armed schedule ids, skipped count, and failures. | App info and performance, diagnostics, device or other identifiers | Source-backed, backend retention pending |
| Local alarm registry | Scheduled alarm records are stored locally with schedule id, alarm time, preparation start time, fingerprint, notification ids, provider, schedule title, and payload. | On-device storage; disclose only if transmitted or shared elsewhere | Source-backed |
| Android permissions | Release manifest includes notification, exact alarm, full-screen intent, boot restore, vibration, and dependency-owned network/Firebase/sign-in permissions. It does not include location, contacts, camera, microphone, phone, SMS, storage, calendar, nearby-device, or Bluetooth permissions. | Permission/API evidence for form consistency | Source-backed by #442 |
| Firebase Cloud Messaging SDK | The app uses `firebase_core` and `firebase_messaging`. Firebase documentation says Cloud Messaging collects app version automatically and depends on Firebase Installations; FID and Firebase user agent handling must be considered. | SDK-collected data, device or other identifiers, app info and performance | Source-backed dependency, final SDK review pending |
| Google Play services core SDKs | Google Play services base/basement/tasks may be present through dependencies. Google's disclosure page says the listed core SDKs do not collect end-user data, but app owners remain responsible for the overall disclosure. | SDK review | Dependency review pending |

## Answers That Must Stay Pending

Do not finalize these fields until the owners listed below provide the missing
facts.

| Field or decision | Required owner input |
| --- | --- |
| Whether each collected data type is required or optional | Product owner and source review. |
| Whether any data is shared outside service-provider processing | Backend owner, Firebase/Google configuration owner, and privacy owner. |
| Backend retention period for accounts, schedules, preparations, feedback, FCM tokens, device registrations, alarm status, and logs | Backend owner. |
| Whether deletion requests delete or anonymize each associated data type, and within what time window | Backend owner and privacy owner. |
| Whether any data is retained for legal compliance, security, abuse prevention, or operations | Backend owner and legal/product owner. |
| Final privacy policy URL and exact text | Product/legal owner and #434/#435. |
| External account deletion request URL and page content | Web/backend owner and #440. |
| Final active auth providers for Android release | Release owner. Current source supports normal, Google, and Apple paths; Kakao dependencies are present but no active release flow was found in the checked auth path. |
| Firebase optional exports such as FCM delivery metrics to BigQuery or Analytics-linked notification interaction events | Firebase project owner. No Analytics dependency was found in `pubspec.yaml`, but console settings must still be checked. |
| Play Console submission | Play Console owner. |

## Pre-Submission Checklist

1. Confirm the release build's exact dependency set and SDK configuration.
2. Re-run the source audit after final release branch changes.
3. Confirm backend deletion and retention behavior for normal, Google, and Apple
   account paths.
4. Approve the privacy policy and verify every declared data type appears in it.
5. Verify the public privacy policy URL works without login and is the same URL
   used in app and Play Console.
6. Verify the public account deletion URL works without installing or opening
   the app and explains deleted and retained data.
7. Enter the Data safety form in Play Console from this worksheet plus approved
   owner answers.
8. Save the final submitted answers back into release documentation, replacing
   or appending to this worksheet.

## Suggested Final Documentation Template

After Play Console submission, append a section named `Submitted Answers` with:

- Submission date and Play Console owner.
- Privacy policy URL.
- Account deletion URL.
- Data types declared as collected.
- Data types declared as shared, if any.
- Purpose, required/optional status, and deletion support for each data type.
- Encryption in transit answer.
- Any retained data exceptions and retention period.
- Evidence screenshots or links stored outside git, if applicable.
