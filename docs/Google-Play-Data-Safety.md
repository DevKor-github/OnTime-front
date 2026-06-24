# Google Play Data Safety Worksheet

This worksheet advances release issue #441 under parent track #464. The Google
Play Data safety questionnaire was completed and saved in Play Console on
2026-05-10 using the answers recorded below. The privacy policy URL was also
saved in Play Console on 2026-05-10. The app-content submission is still blocked
by separate Play Console requirements outside the Data safety form.

## Status

Current status: Data safety questionnaire saved in Play Console; app-content
submission externally blocked.

Blocking prerequisites:

| Input | Source issue | Status on 2026-05-10 | Why it blocks submission |
| --- | --- | --- | --- |
| Approved and hosted privacy policy URL | #434/#435/#437 | Hosting/Play entry complete; #434 approval still open | Public URL is `https://ontime-back.duckdns.org/privacy-policy` and is saved in Play Console. Product/legal approval of final text remains tracked by #434. |
| Backend deletion and retention truth | #439 | Closed with static backend evidence | Data deletion support, retention exceptions, and associated data deletion are documented; production retention enforcement still needs owner confirmation before final submission. |
| External account deletion request URL | #440 | Closed | Public URL is `https://ontime-back.duckdns.org/account-deletion`; Play Console delete account URL field is saved in the Data safety draft. |
| Manifest permission audit | #442 | Closed | Evidence is available in `docs/Android-Manifest-Permissions.md`. |
| Target audience and content | Play Console app content | Open, manual | Play Console preview says submission requires target age group and other content information. |
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
- `docs/Analytics-Preference-API.md`
- `docs/Analytics-Event-Catalog.md`

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
| Android permissions | Release manifest includes notification, exact alarm, boot restore, vibration, and dependency-owned network/Firebase/sign-in permissions. It does not include full-screen intent, location, contacts, camera, microphone, phone, SMS, storage, calendar, nearby-device, or Bluetooth permissions. | Permission/API evidence for form consistency | Source-backed by #442 |
| Firebase Cloud Messaging SDK | The app uses `firebase_core` and `firebase_messaging`. Firebase documentation says Cloud Messaging collects app version automatically and depends on Firebase Installations; FID and Firebase user agent handling must be considered. | SDK-collected data, device or other identifiers, app info and performance | Source-backed dependency, final SDK review pending |
| Firebase Analytics Product Usage Events | Planned analytics release uses Firebase Analytics for workflow milestone events only, with Help Improve OnTime opt-out, pseudonymous analytics identifiers, schema-versioned event names, app version, platform, workflow result, stable error categories, and coarse counts or durations. The event catalog forbids raw schedule names, notes, place names, preparation step names, email, OAuth identifiers, FCM token, raw exceptions, request bodies, response bodies, and free text. | App activity, app info and performance, device or other identifiers; purposes include Analytics, app functionality, debugging and operations, and non-personalized experiments | Planned; not present in current `pubspec.yaml` until `firebase_analytics` is added |
| Google Play services core SDKs | Google Play services base/basement/tasks may be present through dependencies. Google's disclosure page says the listed core SDKs do not collect end-user data, but app owners remain responsible for the overall disclosure. | SDK review | Dependency review pending |

## Saved Play Console Answers

Entered in Play Console by `jjoonleo@gmail.com` on 2026-05-10.

Important: these saved answers predate the planned Firebase Analytics release.
Do not submit a build that includes Firebase Analytics until the privacy policy,
Firebase console settings, SDK data handling, and Play Data safety answers below
are reviewed and updated.

Security and deletion:

- Required user data types collected or shared: Yes.
- Data encrypted in transit: Yes.
- Account creation methods: Username and password, OAuth.
- Account deletion URL:
  `https://ontime-back.duckdns.org/account-deletion`.
- Data shared with third parties: No data shared with third parties, using
  Play's service-provider sharing interpretation.

Data types declared as collected:

| Category | Data type | Collected/shared | Ephemeral | Required/optional | Purposes |
| --- | --- | --- | --- | --- | --- |
| Personal info | Name | Collected | Not ephemeral | Required | App functionality, Account management |
| Personal info | Email address | Collected | Not ephemeral | Required | App functionality, Account management |
| Personal info | User IDs | Collected | Not ephemeral | Required | App functionality, Account management |
| App info and performance | Diagnostics | Collected | Not ephemeral | Required | App functionality, Analytics |
| App activity | App interactions | Collected | Not ephemeral | Required | App functionality |
| App activity | Other user-generated content | Collected | Not ephemeral | Optional | App functionality |
| Device or other IDs | Device or other IDs | Collected | Not ephemeral | Required | App functionality |

Play Console preview showed:

- Data shared: no data shared with third parties.
- Data collected: Personal info, App info and performance, App activity, Device
  or other IDs.
- Data deletion: account and associated data can be deleted via the saved
  account deletion URL.
- Security practices: data is encrypted in transit.
- Remaining blocker shown by Play Console before final app-content submission:
  target audience/content.

## Firebase Analytics Release Delta

Before releasing a build with Firebase Analytics, the release owner must revise
the saved Play Console answers to cover Help Improve OnTime and Product Usage
Events:

| Area | Required review |
| --- | --- |
| SDK/provider set | Add `firebase_analytics` to the reviewed SDK set and confirm Firebase console settings, optional exports, linked Google services, and whether service-provider sharing remains accurate. |
| App activity | Confirm `App interactions` covers workflow milestone Product Usage Events and mark the analytics collection as optional if the user can disable Help Improve OnTime and still use the app. |
| App info and performance | Confirm diagnostics or crash/error categories used for `alarm_failed` and debugging/operations are declared with the correct purpose. |
| Device or other IDs | Confirm Firebase installation or analytics identifiers and pseudonymous analytics subject handling are declared correctly. |
| Purposes | Add or confirm Analytics as a purpose for Product Usage Events, with app functionality/debugging where appropriate. Marketing and personalization remain out of scope. |
| Data deletion | Confirm account deletion stops future user-linked events and that historical analytics is retained only in aggregate or de-identified form. |
| Required vs optional | Confirm whether each analytics-related data type is optional because Help Improve OnTime can be disabled. |

## Answers That Still Need Owner Confirmation

The Play Console draft is saved, but the owners below should still confirm these
facts before final release submission.

| Field or decision | Required owner input |
| --- | --- |
| Whether any data is shared outside service-provider processing | Backend owner, Firebase/Google configuration owner, and privacy owner. |
| Backend retention period for accounts, schedules, preparations, feedback, FCM tokens, device registrations, alarm status, and logs | Backend owner. |
| Whether deletion requests delete or anonymize each associated data type, and within what time window | Backend owner and privacy owner. |
| Whether any data is retained for legal compliance, security, abuse prevention, or operations | Backend owner and legal/product owner. |
| Final privacy policy text approval | Product/legal owner and #434. Hosted URL is `https://ontime-back.duckdns.org/privacy-policy`. |
| External account deletion request URL and page content | Closed in #440: `https://ontime-back.duckdns.org/account-deletion`. |
| Final active auth providers for Android release | Release owner. Current source supports normal, Google, and Apple paths; Kakao dependencies are present but no active release flow was found in the checked auth path. |
| Firebase Analytics release readiness | Firebase project owner, privacy owner, and release owner. Confirm `firebase_analytics` SDK behavior, console settings, optional exports, linked Google services, Help Improve OnTime opt-out behavior, and Play Data safety changes before release. |
| Firebase optional exports such as FCM delivery metrics to BigQuery or Analytics-linked notification interaction events | Firebase project owner. Confirm whether optional exports or Analytics-linked notification interaction events are enabled. |
| Play Console app-content submission | Play Console owner after target audience/content is complete. |

## Pre-Submission Checklist

1. Confirm the release build's exact dependency set and SDK configuration.
2. Re-run the source audit after final release branch changes.
3. If Firebase Analytics is included, update the privacy policy and Play Data
   safety answers using the Firebase Analytics Release Delta above.
4. Confirm backend deletion and retention behavior for normal, Google, and Apple
   account paths.
5. Approve the privacy policy and verify every declared data type appears in it.
6. Verify the public privacy policy URL works without login and is the same URL
   used in app and Play Console.
7. Verify the public account deletion URL works without installing or opening
   the app and explains deleted and retained data.
8. Confirm the saved Data safety answers above still match the approved policy
   and final release build.
9. Send the saved changes for review from Publishing overview after the
   remaining app-content blockers are resolved.

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
