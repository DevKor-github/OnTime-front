# OnTime Privacy Policy Draft

Draft status: not approved for publication. Prepared for issue #434 under
parent track #464 on 2026-05-10.

Do not publish this document until every `TODO` is resolved and a product/legal
owner approves the final text. Backend account and data deletion behavior is
still pending verification in #439, so the retention and deletion language below
is intentionally incomplete.

## Approval Blockers

- TODO: Replace `[Developer legal entity]` with the exact developer or company
  name used in the Google Play listing.
- TODO: Replace `[privacy contact]` with the support email, contact form, or
  other privacy inquiry mechanism approved by the release owner.
- TODO: Replace `[effective date]` with the final publication date.
- TODO: Complete the account deletion and retained-data sections after #439
  confirms backend behavior by auth provider and data type.
- TODO: Product/legal owner must approve the final text before #434 can close.

## Draft Policy Text

### Privacy Policy

Effective date: `[effective date]`

OnTime is provided by `[Developer legal entity]`. This Privacy Policy explains
how OnTime collects, uses, shares, protects, retains, and deletes data when you
use the OnTime app.

For privacy questions or requests, contact `[privacy contact]`.

### Data OnTime Collects Or Accesses

OnTime collects or accesses the following data to provide accounts, schedules,
preparation reminders, alarms, and support features:

| Data | Examples | Purpose |
| --- | --- | --- |
| Account data | Email address, display name, password for email sign-up, Google sign-in token, Apple identity token, Apple authorization code, Apple-provided name or email when available | Create and authenticate accounts, keep users signed in, support social sign-in, and load user profile information |
| Schedule data | Schedule ID, schedule name, schedule time, place name, place ID, movement time, spare time, notes, started/changed state, lateness time | Create, update, display, finish, and delete schedules |
| Preparation data | Default preparation steps, schedule-specific preparation steps, preparation names, preparation durations, step order, spare time | Help users plan preparation steps and reminders before schedules |
| Alarm and notification data | Alarm settings, notification permission state, device ID, FCM token, platform, app version, OS version, supported alarm providers, alarm status reports, armed or skipped schedule IDs, alarm failure reason | Deliver schedule reminders and alarm notifications, register the current device, restore alarms after device restart, and diagnose alarm coverage |
| Feedback data | Optional account deletion feedback or other feedback message | Process user feedback and account deletion requests |
| Local app data | Cached user, schedule, place, preparation, alarm, and token data stored on the device | Keep app state available locally and support app operation |
| Technical data | Network request metadata, server logs, error metadata, and security-related operational records | Operate, secure, debug, and maintain the service |

OnTime does not request app-owned access to location, contacts, camera,
microphone, phone, SMS, storage, calendar, nearby-device, or Bluetooth
permissions in the current Android release manifest. OnTime uses notification,
exact alarm, full-screen intent, boot completion, vibration, Firebase messaging,
and network-related permissions to provide schedule reminders and alarm
functionality.

### How OnTime Uses Data

OnTime uses collected data to:

- Create, authenticate, and manage user accounts.
- Support email/password, Google, and Apple sign-in.
- Create, update, finish, delete, and display schedules.
- Create and update default and schedule-specific preparation steps.
- Send schedule reminders, preparation notifications, and alarm notifications.
- Register and unregister the current device for alarm and notification
  delivery.
- Process optional feedback and account deletion feedback.
- Maintain security, prevent abuse, debug failures, and operate the service.

### Third-Party Services And Processors

OnTime uses third-party services and SDKs where needed for core app behavior:

| Service or SDK | Purpose | Data involved |
| --- | --- | --- |
| Google Sign-In | Google account authentication | Google account authentication data, including ID token and profile scopes for email/profile |
| Apple Sign-In | Apple account authentication | Apple identity token, authorization code, and Apple-provided name or email when available |
| Firebase Core and Firebase Cloud Messaging | App initialization and push notification delivery | Firebase installation or messaging identifiers, FCM token, notification delivery data, and device-related messaging metadata |
| OnTime backend/API infrastructure | Account, schedule, preparation, alarm, notification, feedback, and deletion request processing | The account, schedule, preparation, alarm, notification, feedback, and technical data listed above |

TODO: Confirm whether Kakao SDK is present only as an unused dependency for this
release. If Kakao sign-in or Kakao SDK data processing is active in the release
build, add Kakao to this table and update the Data safety form accordingly.

TODO: Confirm the backend hosting, database, logging, monitoring, analytics, and
crash-reporting providers used outside this frontend repository, then add each
approved provider to this table if it processes personal or sensitive user data.

### Data Sharing

OnTime shares data with service providers only as needed to provide app
functionality, authentication, notifications, hosting, security, operations, and
support. OnTime does not use in-app advertising in the current release build.

TODO: Product/legal owner must confirm whether any backend, analytics,
monitoring, support, or legal/compliance sharing occurs outside the app code
reviewed here.

### Secure Data Handling

OnTime uses HTTPS API communication, token-based authentication, local secure
token storage, release-log restrictions, and redaction practices to protect
personal and sensitive data. Release builds must not log tokens, authorization
headers, request bodies, response bodies, personal schedule payloads, full alarm
payloads, OAuth values, or FCM tokens.

TODO: Backend owner must confirm server-side encryption, access controls,
backup handling, production logging controls, incident response, and retention
controls.

### Data Retention

OnTime keeps account, schedule, preparation, alarm, notification, feedback, and
technical data for as long as needed to provide the service, maintain security,
meet legal obligations, resolve disputes, and enforce agreements.

TODO: Replace this general language with exact retention periods after #439
confirms:

- Whether user account records are deleted immediately, soft-deleted, anonymized,
  or retained for a period after deletion.
- Whether schedule, place, preparation, alarm settings, device registrations,
  FCM tokens, alarm status reports, and feedback are deleted with the account.
- Whether server logs, backups, audit records, abuse-prevention records, or
  legal/compliance records are retained after account deletion.
- The retention period and reason for each retained data type.

### Account And Data Deletion

Users can request account deletion from within the OnTime app. The current
frontend routes deletion requests through separate backend endpoints for normal,
Google, and Apple account types, and supports optional deletion feedback. On
successful deletion, the app signs the user out.

TODO: Finalize this section only after #439 verifies backend behavior. The final
policy must clearly state:

- How users request deletion in the app.
- How users request deletion outside the app after #440 creates the public
  deletion request URL.
- Which account data and associated user data are deleted.
- Which data, if any, is retained after deletion.
- Why retained data is kept and for how long.
- Whether deletion covers Google and Apple social account paths consistently.

### Children

TODO: Product/legal owner must confirm the intended audience and Google Play
target age settings before publication. If OnTime is not directed to children,
state that clearly. If children may use the app, complete the required child
privacy and Play Families review before publication.

### Changes To This Policy

OnTime may update this Privacy Policy to reflect changes in app behavior, legal
requirements, or service providers. The effective date above will be updated
when the policy changes.

## Release Owner Checklist

- [ ] Developer/entity name matches the Google Play listing.
- [ ] Privacy contact method is approved and monitored.
- [ ] #439 backend deletion and retention behavior is verified by data type.
- [ ] #440 external account deletion request URL exists or the policy links to
      the approved deletion request path when available.
- [ ] All active third-party SDKs and backend processors are listed.
- [ ] Data categories match the shipped app and the Play Console Data safety
      form.
- [ ] Retention and deletion language matches backend behavior.
- [ ] Product/legal owner approves the final text.
- [ ] Approved policy is handed to #435 for public HTTPS hosting.
- [ ] Hosted policy URL is entered in Play Console in #437.

## References

- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play app account deletion requirements:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play Data safety form guidance:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Local app data-flow review sources: `lib/data/data_sources/`,
  `lib/core/constants/endpoint.dart`, `lib/data/tables/`,
  `android/app/src/main/AndroidManifest.xml`, `docs/Android-Manifest-Permissions.md`,
  and `docs/Logging-Policy.md`.
