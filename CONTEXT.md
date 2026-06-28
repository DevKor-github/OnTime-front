# OnTime Front

This context defines product language for the OnTime Flutter app so analytics,
release, and feature discussions use the same terms.

## Language

**Product Usage Event**:
A named record that a user performed a product-relevant action, excluding raw personal content.
_Avoid_: User activity, tracking event, raw interaction log

**Analytics Purpose**:
The approved reason a Product Usage Event may be collected or used.
_Avoid_: Use case, tracking reason

**Experiment**:
A pseudonymous feature or configuration comparison used for product improvement.
_Avoid_: Personalization, marketing campaign, user targeting

**Deferred Analytics Purpose**:
An Analytics Purpose that is recognized but not active until a later privacy and consent review approves it.
_Avoid_: Future tracking, inactive use case

**Pseudonymous Analytics Subject**:
The non-directly-identifying actor associated with a Product Usage Event.
_Avoid_: User identity, personal identity, email identity

**Analytics Preference**:
The user's current choice about whether optional Product Usage Events may be collected.
_Avoid_: Tracking consent, privacy switch

**Help Improve OnTime**:
The user-facing name for the Analytics Preference.
_Avoid_: Tracking, marketing analytics, personalization

**Analytics Provider**:
An external service approved to receive Product Usage Events.
_Avoid_: Tracking vendor, analytics SDK

**Workflow Milestone Event**:
A Product Usage Event that marks completion or failure of a meaningful user workflow step.
_Avoid_: Tap event, raw navigation log, interaction trace

**Provider Authentication Completed**:
The state where the external Apple or Google account prompt has returned credentials to OnTime.
_Avoid_: Login completed, signed in, session ready

**OnTime Session Established**:
The state where OnTime has accepted provider credentials, created an app session, and can route the user into the signed-in app experience.
_Avoid_: Provider login completed, credential received

**Analytics Event Parameter**:
An allowlisted non-content value attached to a Product Usage Event.
_Avoid_: Event payload, arbitrary metadata, raw detail

**Schedule**:
A planned commitment with an appointment time and place that OnTime helps the user prepare for.
_Avoid_: Calendar event, meeting

**Preparation**:
The set of user-planned steps completed before leaving for a Schedule.
_Avoid_: Prep routine, checklist

**Preparation Duration**:
The sum of a Schedule's Preparation step durations, excluding move time and Schedule Spare Time.
_Avoid_: Total duration, travel time, buffer time

**Schedule Spare Time**:
A user buffer before a Schedule's appointment time, separate from travel time and Preparation Duration.
_Avoid_: Preparation time, move time

**Schedule Notification**:
A user-facing notification that starts preparation for a scheduled commitment at the intended moment.
_Avoid_: Schedule alarm, alarm, push

**Schedule Notification Setting**:
The user-facing setting that controls whether OnTime sends notifications for upcoming schedule preparation.
_Avoid_: Schedule alarm setting, alarm switch

**Alarm**:
An alarm experience that opens an OnTime screen over the lock screen or current app without the user first tapping a notification.
_Avoid_: Notification, alert, push

**iOS AlarmKit Alarm**:
The iOS alarm experience OnTime may use when the device and build support AlarmKit.
_Avoid_: iOS notification, fallback notification

**Android Schedule Notification**:
The Android presentation that alerts the user through a notification instead of an Alarm.
_Avoid_: Android alarm, native alarm UI

**Precise Notification Timing**:
The expectation that a Schedule Notification is delivered at the intended preparation start moment.
_Avoid_: Best-effort reminder, approximate notification

**Fallback Notification**:
A secondary delivery path used only when Precise Notification Timing is unavailable.
_Avoid_: Alarm, alarm permission

**Exact Timing Permission**:
The user's permission for OnTime to schedule notifications at precise times on devices that require it.
_Avoid_: Alarm permission, notification permission

**No Scheduled Notification**:
The state where notifications are enabled but no Schedule Notification is currently armed for an upcoming schedule.
_Avoid_: Pending, waiting, permission pending

**Approximate Notification Timing**:
The state where OnTime may notify the user for a schedule but cannot guarantee delivery at the exact preparation time.
_Avoid_: Disabled notifications, alarm denied

**Precise Notification Status**:
The user-facing status for a Schedule Notification that can be delivered with Precise Notification Timing.
_Avoid_: Native alarm, exact alarm

**Notification Status**:
The user-facing status for schedule delivery through notifications when Alarm delivery or Precise Notification Timing is unavailable.
_Avoid_: Fallback, degraded, time sensitive

**Alarm Status**:
The user-facing status for schedule delivery through an Alarm.
_Avoid_: Notification, native alarm

## Relationships

- A **Product Usage Event** may describe a schedule, preparation, notification, alarm, onboarding, or account action without storing the user's raw schedule names, notes, place names, credentials, tokens, or free text.
- First-release **Product Usage Events** are **Workflow Milestone Events**, not every tap or raw navigation step.
- First-release **Workflow Milestone Events** cover analytics preference, onboarding, authentication, schedule, notification permission, alarm, and schedule-finish outcomes.
- **Provider Authentication Completed** precedes **OnTime Session Established** during Apple or Google sign-in.
- **Provider Authentication Completed** does not mean the user is signed in to OnTime.
- The signed-in app experience begins only after **OnTime Session Established**.
- A **Product Usage Event** may include **Analytics Event Parameters** such as workflow, result, stable error category, coarse count, coarse duration, platform, or app version.
- An **Analytics Event Parameter** must not contain user-authored text, direct identifiers, tokens, raw exception strings, request bodies, or response bodies.
- A **Product Usage Event** uses a stable snake_case name and includes a schema version.
- A changed **Product Usage Event** meaning requires a new event name or schema version.
- A **Schedule** has a **Preparation** whose **Preparation Duration** contributes to preparation-start timing.
- **Preparation Duration**, move time, and **Schedule Spare Time** are distinct schedule timing inputs.
- User-facing copy should call a scheduled notification a **Schedule Notification**, not an **Alarm**, unless it opens an OnTime screen without the user first tapping a notification.
- The profile setting for upcoming schedule preparation delivery should be called **Schedule Notification Setting**.
- On iOS, user-facing copy may say **Alarm** only when OnTime can deliver an **iOS AlarmKit Alarm**.
- iOS permission prompts should use alarm language only when requesting an **iOS AlarmKit Alarm**; otherwise they should use notification language.
- When an **iOS AlarmKit Alarm** is unavailable or denied but notifications are allowed, user-facing status should say notification rather than expose Time Sensitive terminology.
- A **Schedule Notification** should use **Precise Notification Timing** when the user's device supports it and **Exact Timing Permission** is granted.
- A **Fallback Notification** may back up a **Schedule Notification**, but it does not satisfy **Exact Timing Permission**.
- On Android, OnTime should use an **Android Schedule Notification** unless **Alarm** policy approval is available.
- Android permission prompts for scheduled preparation delivery should say notification, not alarm, unless OnTime is requesting or explaining an **Alarm** experience.
- Android **Exact Timing Permission** copy should explain that the permission is needed to notify the user at the exact preparation time.
- **Exact Timing Permission** is granted only when the device reports it as granted, not when the user taps a permission request button.
- **No Scheduled Notification** does not indicate a missing **Exact Timing Permission**.
- Missing **Exact Timing Permission** means **Approximate Notification Timing**, not disabled notifications, when notification permission is granted.
- Android with **Precise Notification Timing** should show **Precise Notification Status**.
- Android without **Precise Notification Timing** but with notification permission should show **Notification Status**.
- iOS with an **iOS AlarmKit Alarm** should show **Alarm Status**.
- iOS without an available **iOS AlarmKit Alarm** but with notification permission should show **Notification Status**.
- **No Scheduled Notification** should be the user-facing empty state across platforms, even when future delivery may use an **Alarm**.
- Active first-release **Analytics Purposes** are product improvement, debugging and operations, and experimentation.
- A first-release **Experiment** must not be used for marketing targeting, sensitive segmentation, or personalized treatment.
- Marketing and personalization are **Deferred Analytics Purposes**.
- A **Product Usage Event** belongs to a **Pseudonymous Analytics Subject**, using an internal user or analytics identifier for signed-in use and an installation identifier before sign-in.
- A **Pseudonymous Analytics Subject** must not be an email address, display name, OAuth identifier, FCM token, or raw personal content value.
- The first-release **Analytics Preference** is opt-out for active Analytics Purposes.
- A disabled **Analytics Preference** stops future optional Product Usage Events.
- Before sign-in, the **Analytics Preference** is installation-scoped.
- After sign-in, the **Analytics Preference** is account-scoped and should apply across the user's signed-in devices.
- Before sign-in, a **Product Usage Event** may be associated only with an installation-scoped **Pseudonymous Analytics Subject**.
- After sign-in, future **Product Usage Events** may be associated with a signed-in **Pseudonymous Analytics Subject**.
- After sign-out, future **Product Usage Events** return to an installation-scoped **Pseudonymous Analytics Subject**.
- Account deletion stops future user-linked **Product Usage Events** and may retain historical analytics only in aggregate or de-identified form.
- A first-release **Analytics Provider** may receive Product Usage Events only after privacy, Data Safety, retention, and deletion responsibilities are approved.

## Example dialogue

> **Dev:** "Should the analytics event include the schedule note so we can understand why users are late?"
> **Domain expert:** "No. A **Product Usage Event** can say a schedule was finished late, but it must not include the user's raw note."

## Flagged ambiguities

- "User activities" was used broadly; resolved: the canonical term is **Product Usage Event**, and raw personal content is out of scope.
- "Analytics" was used to include all possible purposes; resolved: marketing and personalization are deferred, not first-release purposes.
- "User identity" for analytics was ambiguous; resolved: analytics uses a **Pseudonymous Analytics Subject**, not directly identifying user data.
- "Consent" was ambiguous for analytics; resolved: first-release analytics is opt-out with a user-visible **Analytics Preference**.
- "Third party" was ambiguous for analytics; resolved: the canonical term is **Analytics Provider**.
- "Event taxonomy" was broad; resolved: first-release analytics tracks **Workflow Milestone Events** only.
- "Event payload" was too open-ended; resolved: events use allowlisted **Analytics Event Parameters** only.
- "Login completed" was ambiguous for Apple and Google sign-in; resolved: external account prompt completion is **Provider Authentication Completed**, while usable OnTime sign-in is **OnTime Session Established**.
- "Alarm permission" was ambiguous between **Exact Timing Permission** and notification permission; resolved: notification permission may enable a **Fallback Notification**, but does not mean **Exact Timing Permission** is granted.
- "Pending" was ambiguous for notification status; resolved: the canonical state is **No Scheduled Notification** when notifications are enabled but no upcoming Schedule Notification is armed.
- "Allowed" was ambiguous for permission requests; resolved: a request action is not the same as granted **Exact Timing Permission**.
- "Native alarm" was ambiguous on Android; resolved: Android can use an **Android Schedule Notification** without promising an **Alarm**.
- "Fallback" was ambiguous as either a backup delivery path or permission bypass; resolved: Android's notification-only path should not be labeled fallback when it is the intended policy-safe path.
- "Notification-only alarm" was ambiguous as either approximate or precise; resolved: Android should keep **Precise Notification Timing** while using an **Android Schedule Notification** presentation.
- "Notification" was ambiguous as either a user-facing alarm concept or a platform presentation; resolved: user-facing copy should say **Schedule Notification** unless the experience is an **Alarm**.
- "Allow alarms" was ambiguous on Android; resolved: permission prompts should say notifications when the resulting user experience is notification-based.
- "Denied exact timing" was ambiguous as either disabled delivery or degraded delivery; resolved: with notification permission granted, it means **Approximate Notification Timing**.
- "Schedule alarm setting" was ambiguous after Android moved to notification-based delivery; resolved: the profile control is **Schedule Notification Setting**.
- "iOS alarm" was ambiguous across OS versions; resolved: iOS copy may say **Alarm** only when **iOS AlarmKit Alarm** is available.
- "iOS alarm permission" was ambiguous across OS versions; resolved: iOS permission prompts use alarm language only for **iOS AlarmKit Alarm**.
- "Time Sensitive" was too platform-specific for default user-facing status; resolved: fallback iOS delivery should be called notification.
- "Status label" was ambiguous across platforms; resolved: Android uses precise notification or notification status, while iOS uses alarm status only for **iOS AlarmKit Alarm**.
- "No scheduled alarm" was too capability-specific for an empty state; resolved: use **No Scheduled Notification** across platforms.
- "Total duration" was ambiguous between **Preparation Duration** and the broader preparation-start timing calculation; resolved: **Preparation Duration** is steps only, while move time and **Schedule Spare Time** are separate inputs.
