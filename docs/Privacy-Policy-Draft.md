# OnTime Privacy Policy Draft

Draft status: hosted for Play Console use, with product/legal approval still
pending. Prepared for issue #434 under parent track #464 on 2026-05-10.

Do not mark #434 complete until every `TODO` is resolved and a product/legal
owner approves the final text. Backend account and data deletion behavior has
code-reviewed evidence in #439, but release-environment provider unlink,
logging, monitoring, backup, and retention-period decisions still need owner
confirmation.

## Approval Blockers

- TODO: Backend/environment owner must confirm the service can enforce the
  retention periods listed in this draft.
- TODO: Product/legal owner must approve Firebase Analytics wording before any
  release that enables Help Improve OnTime.
- TODO: Backend-hosted privacy policy update is tracked in
  DevKor-github/OnTime-back#319 for the Firebase Analytics release handoff.
- TODO: Product/legal owner must approve the final text before #434 can close.

## Draft Policy Text

### Privacy Policy

Public URL: https://ontime-back.duckdns.org/privacy-policy

Effective date: May 10, 2026

OnTime is provided by ejun. This Privacy Policy explains
how OnTime collects, uses, shares, protects, retains, and deletes data when you
use the OnTime app.

For privacy questions or requests, contact jjoonleo@gmail.com.

### Data OnTime Collects Or Accesses

OnTime collects or accesses the following data to provide accounts, schedules,
preparation reminders, alarms, and support features:

| Data                        | Examples                                                                                                                                                                                                     | Purpose                                                                                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Account data                | Email address, display name, password for email sign-up, Google sign-in token, Apple identity token, Apple authorization code, Apple-provided name or email when available                                   | Create and authenticate accounts, keep users signed in, support social sign-in, and load user profile information                                 |
| Schedule data               | Schedule ID, schedule name, schedule time, place name, place ID, movement time, spare time, notes, started/changed state, lateness time                                                                      | Create, update, display, finish, and delete schedules                                                                                             |
| Preparation data            | Default preparation steps, schedule-specific preparation steps, preparation names, preparation durations, step order, spare time                                                                             | Help users plan preparation steps and reminders before schedules                                                                                  |
| Alarm and notification data | Alarm settings, notification permission state, device ID, FCM token, platform, app version, OS version, supported alarm providers, alarm status reports, armed or skipped schedule IDs, alarm failure reason | Deliver schedule reminders and alarm notifications, register the current device, restore alarms after device restart, and diagnose alarm coverage |
| Feedback data               | Optional account deletion feedback or other feedback message                                                                                                                                                 | Process user feedback and account deletion requests                                                                                               |
| Local app data              | Cached user, schedule, place, preparation, alarm, and token data stored on the device                                                                                                                        | Keep app state available locally and support app operation                                                                                        |
| Technical data              | Network request metadata, server logs, error metadata, and security-related operational records                                                                                                              | Operate, secure, debug, and maintain the service                                                                                                  |
| Product usage analytics data | Privacy-safe event names, app version, platform, workflow result, stable error category, coarse counts or durations, Analytics Preference, and pseudonymous analytics identifiers                            | Improve OnTime, debug and operate the service, and run non-personalized experiments when Help Improve OnTime is enabled                            |

OnTime does not request app-owned access to location, contacts, camera,
microphone, phone, SMS, storage, calendar, nearby-device, or Bluetooth
permissions in the current Android release manifest. OnTime uses notification,
exact alarm, boot completion, vibration, Firebase messaging, and network-related
permissions to provide schedule reminders and alarm functionality.

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
- Collect privacy-safe Product Usage Events when Help Improve OnTime is enabled
  to improve OnTime, debug and operate the service, and run non-personalized
  experiments.

### Third-Party Services And Processors

OnTime uses third-party services and SDKs where needed for core app behavior:

| Service or SDK                             | Purpose                                                                                       | Data involved                                                                                                                 |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Google Sign-In                             | Google account authentication                                                                 | Google account authentication data, including ID token and profile scopes for email/profile                                   |
| Apple Sign-In                              | Apple account authentication                                                                  | Apple identity token, authorization code, and Apple-provided name or email when available                                     |
| Firebase Core and Firebase Cloud Messaging | App initialization and push notification delivery                                             | Firebase installation or messaging identifiers, FCM token, notification delivery data, and device-related messaging metadata  |
| Firebase Analytics                         | Privacy-safe Product Usage Events for product improvement, debugging and operations, and non-personalized experiments when Help Improve OnTime is enabled | Product usage analytics data, app/device metadata handled by Firebase, and pseudonymous analytics identifiers |
| OnTime backend/API infrastructure          | Account, schedule, preparation, alarm, notification, feedback, analytics preference, and deletion request processing | The account, schedule, preparation, alarm, notification, feedback, analytics preference, and technical data listed above |

TODO: Confirm whether Kakao SDK is present only as an unused dependency for this
release. If Kakao sign-in or Kakao SDK data processing is active in the release
build, add Kakao to this table and update the Data safety form accordingly.

TODO: Confirm Firebase Analytics console settings, including whether any exports
or Google integrations are enabled, before release.

TODO: Confirm the backend hosting, database, logging, monitoring, and
crash-reporting providers used outside this frontend repository, then add each
approved provider to this table if it processes personal or sensitive user data.

### Data Sharing

OnTime shares data with service providers only as needed to provide app
functionality, authentication, notifications, hosting, security, operations, and
support. When Help Improve OnTime is enabled, OnTime uses Firebase Analytics as
an analytics service provider for privacy-safe Product Usage Events. OnTime does
not use in-app advertising in the current release build.

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

Based on #439 backend code-review evidence, when an OnTime account is deleted,
the local OnTime backend hard-deletes the user account row. Database cascades and
automated backend tests cover deletion of associated schedules, schedule
preparation steps, notification schedules, default preparation settings, general
feedback, user settings, alarm settings, alarm status, device records, FCM
tokens, and session tokens.

If a user submits optional account deletion feedback, OnTime retains that
feedback separately from the deleted account. The retained deletion feedback may
include the feedback ID, previous OnTime user ID, social sign-in type, SHA-256
hash of the normalized email address, feedback message, and creation timestamp.
OnTime retains optional account deletion feedback for up to 1 year to review
service quality and deletion-related support issues.

When an account is deleted, OnTime stops future user-linked Product Usage Events
and clears the app's Firebase Analytics user association. Historical analytics
may be retained only in aggregate or de-identified form for product improvement,
debugging and operations, and non-personalized experiments.

Operational logs, monitoring records, and security records may be retained for
up to 90 days for service operation, debugging, security, and abuse-prevention
purposes, unless a longer period is required for legal compliance or an active
security investigation.

Backup copies that contain deleted account data are removed according to the
normal backup rotation and are retained for no longer than 30 days, unless a
longer period is required by law or an active security investigation.

### Account And Data Deletion

Users can request account deletion from within the OnTime app. The current
frontend routes deletion requests through separate backend endpoints for normal,
Google, and Apple account types, and supports optional deletion feedback. On
successful deletion, the app signs the user out.

Users can also request account deletion outside the app at
https://ontime-back.duckdns.org/account-deletion.

For Google and Apple social accounts, the backend attempts to revoke the stored
provider token before deleting the local OnTime account. If provider token
revocation fails, the backend still deletes the local OnTime account. Deleting an
OnTime account does not delete the user's Google account or Apple ID.

TODO: Backend/environment owner must confirm that production retention settings,
backup rotation, and cleanup jobs match the retention periods in this policy
before publication.

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

- [x] Developer/entity name matches the Google Play listing.
- [x] Privacy contact method uses the verified Play Console developer email.
- [x] #439 backend deletion behavior is documented by data type using static
      backend code-review and automated-test evidence.
- [x] Retained account deletion feedback duration and reason are set in this
      draft.
- [x] Firebase Analytics wording is drafted for Help Improve OnTime, product
      improvement, debugging and operations, and non-personalized experiments.
- [x] Log, monitoring, security record, and backup retention periods are set in
      this draft.
- [ ] Firebase Analytics console settings and optional exports are confirmed.
- [ ] Backend/environment owner confirms production retention settings,
      backup rotation, and cleanup jobs can enforce the draft periods.
- [x] #440 external account deletion request URL exists or the policy links to
      the approved deletion request path when available.
- [ ] All active third-party SDKs and backend processors are listed.
- [ ] Data categories match the shipped app and the Play Console Data safety
      form.
- [ ] Retention and deletion language matches backend behavior.
- [ ] Product/legal owner approves the final text.
- [x] Policy text is handed to #435 for public HTTPS hosting.
- [x] Hosted policy URL is entered in Play Console in #437.
- [ ] Firebase Analytics privacy policy update is handed to
      DevKor-github/OnTime-back#319 before releasing Help Improve OnTime.

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
