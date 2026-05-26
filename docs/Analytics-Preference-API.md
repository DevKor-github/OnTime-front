# Analytics Preference API

This document defines the frontend contract needed before implementing OnTime analytics preference sync. It covers only the account-scoped preference for signed-in users; pre-login installation-scoped preference remains local to the app.

## Scope

- The preference controls optional Product Usage Events for active Analytics Purposes.
- The first release uses opt-out analytics and exposes the setting as Help Improve OnTime.
- Disabled preference stops future optional Product Usage Events.
- Marketing and personalization remain deferred and are not enabled by this API.

## Endpoints

### Get Analytics Preference

```http
GET /users/me/analytics-preference
Authorization: Bearer <access token>
```

Successful response:

```json
{
  "data": {
    "enabled": true,
    "updatedAt": "2026-05-26T12:00:00Z"
  }
}
```

### Update Analytics Preference

```http
PUT /users/me/analytics-preference
Authorization: Bearer <access token>
Content-Type: application/json

{
  "enabled": false
}
```

Successful response:

```json
{
  "data": {
    "enabled": false,
    "updatedAt": "2026-05-26T12:00:05Z"
  }
}
```

## Field Semantics

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `enabled` | boolean | Yes | Whether optional Product Usage Events may be collected for the signed-in account. |
| `updatedAt` | ISO-8601 UTC string | Yes | Server time when the account-scoped preference was last changed. |

## Default Value

- The backend default for existing and newly created signed-in accounts is config-gated.
- The initial config default is `enabled: false` until privacy policy, hosted policy page, Google Play Data Safety, and release approval are complete.
- After approval, the backend may flip the config default to `enabled: true` without changing the API contract.
- An explicit user-saved `enabled` value always wins over the config default.
- The frontend must still treat unknown or load-failed preference state as disabled for optional Product Usage Events.

## Frontend Behavior

1. Before sign-in, the app stores the Analytics Preference locally for the installation.
2. After sign-in, the app loads `GET /users/me/analytics-preference`.
3. After the user changes Help Improve OnTime, the app calls `PUT /users/me/analytics-preference`.
4. If `enabled` is `false`, the app disables Firebase Analytics collection and does not emit future optional Product Usage Events.
5. On sign-out, the app clears the Firebase Analytics user association and returns to the local installation-scoped preference.
6. On account deletion, the app stops future user-linked Product Usage Events and clears the Firebase Analytics user association.

## Failure Behavior

- If loading the signed-in account preference fails, provider collection remains disabled until the preference is loaded successfully.
- If updating the signed-in account preference fails, the app keeps the previous confirmed value and does not emit `analytics_preference_changed`.
- If local installation preference and signed-in account preference conflict, the app uses the stricter value until the user explicitly changes the account preference.
- Unknown preference state is treated as disabled for optional Product Usage Events.

## Backend Handoff Scope

The backend task should be limited to account-scoped Analytics Preference sync:

- Backend issue: DevKor-github/OnTime-back#318.
- Add `GET /users/me/analytics-preference`.
- Add `PUT /users/me/analytics-preference`.
- Persist `enabled` and `updatedAt` for the signed-in account.
- Define the default account value for existing and newly created users.
- Confirm account deletion behavior for historical analytics as aggregate or de-identified retention.
- Confirm privacy policy and Google Play Data Safety updates before release.

The backend task does not need to define Firebase event names, Flutter BLoC instrumentation, local pre-login preference storage, or UI copy.

## Privacy And Release Requirements

- Do not include email, name, OAuth identifiers, FCM token, schedule names, schedule notes, place names, preparation step names, request bodies, response bodies, raw exception strings, or free text in analytics events or preference API payloads.
- Update the privacy policy and Google Play Data Safety worksheet before releasing Firebase Analytics.
- Historical analytics after account deletion may be retained only in aggregate or de-identified form.
- Production analytics is enabled by default only for production builds; debug, local development, tests, and Widgetbook collection require an explicit override.
