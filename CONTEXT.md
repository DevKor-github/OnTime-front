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

**Analytics Event Parameter**:
An allowlisted non-content value attached to a Product Usage Event.
_Avoid_: Event payload, arbitrary metadata, raw detail

## Relationships

- A **Product Usage Event** may describe a schedule, preparation, notification, alarm, onboarding, or account action without storing the user's raw schedule names, notes, place names, credentials, tokens, or free text.
- First-release **Product Usage Events** are **Workflow Milestone Events**, not every tap or raw navigation step.
- First-release **Workflow Milestone Events** cover analytics preference, onboarding, authentication, schedule, notification permission, alarm, and schedule-finish outcomes.
- A **Product Usage Event** may include **Analytics Event Parameters** such as workflow, result, stable error category, coarse count, coarse duration, platform, or app version.
- An **Analytics Event Parameter** must not contain user-authored text, direct identifiers, tokens, raw exception strings, request bodies, or response bodies.
- A **Product Usage Event** uses a stable snake_case name and includes a schema version.
- A changed **Product Usage Event** meaning requires a new event name or schema version.
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
