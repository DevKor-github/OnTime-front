# Analytics Implementation Plan

## Goal

Add privacy-safe Firebase Analytics collection for first-release Product Usage Events, with account-synced opt-out, fail-closed preference handling, and BLoC/Cubit workflow milestone tracking.

## Context

- Canonical analytics language is defined in `CONTEXT.md`.
- Account preference contract is defined in `docs/Analytics-Preference-API.md`.
- First-release event names and parameter allowlists are defined in `docs/Analytics-Event-Catalog.md`.
- ADRs in `docs/adr/` record the provider, BLoC tracking boundary, account deletion retention, production-only default, no automatic screen tracking, account preference sync, and Remote Config deferral.
- Existing user-scoped API endpoints use `/users/me/...`; the analytics preference API follows that pattern.
- Existing app architecture uses clean layers under `lib/core`, `lib/data`, `lib/domain`, and `lib/presentation`, with BLoCs/Cubits owning workflow outcomes.

## Decisions

- Use Firebase Analytics as the first third-party Analytics Provider.
- Track only Workflow Milestone Events, not every tap, automatic screen view, or raw navigation step.
- Emit analytics from feature BLoCs/Cubits via an injected tracking use case, not from a global `BlocObserver`.
- Use strict allowlisted Analytics Event Parameters and include `schema_version: 1`.
- Keep marketing and personalization deferred until a separate privacy and consent review.
- Disable provider collection outside production by default unless explicitly overridden.
- Fail closed when the signed-in Analytics Preference is unknown or cannot be loaded.
- Keep historical analytics after account deletion only in aggregate or de-identified form.
- Do not add Firebase Remote Config until a concrete Experiment exists.

## Steps

1. Backend/API preparation:
   - Track backend work in DevKor-github/OnTime-back#318 using `docs/Analytics-Preference-API.md`.
   - Confirm `GET /users/me/analytics-preference` and `PUT /users/me/analytics-preference`.
   - Use a config-gated backend default that starts as `enabled: false`; flip it to `enabled: true` only after privacy policy, hosted policy page, Play Data Safety, and release approval are complete.
   - Ensure explicit user-saved preference values always win over the config default.
   - Confirm account deletion and historical analytics retention wording.

2. Release/privacy documentation:
   - Update `docs/Privacy-Policy-Draft.md` for Firebase Analytics and Help Improve OnTime.
   - Update `docs/Google-Play-Data-Safety.md` for Firebase Analytics data collection, purposes, provider handling, opt-out, and retention.
   - Hand off the backend-hosted privacy policy page update through DevKor-github/OnTime-back#319 before the Firebase Analytics release.
   - Update release checklist evidence if provider or SDK review requirements change.

3. Preference domain and data layer:
   - Add an `AnalyticsPreference` domain entity or value type.
   - Add repository/use cases for loading and updating the preference.
   - Add remote data source/model support for `/users/me/analytics-preference`.
   - Add local installation-scoped preference storage for pre-login state.
   - Implement stricter-value behavior when local and account preference conflict.

4. Firebase Analytics wrapper:
   - Add `firebase_analytics` only after the release/provider docs are updated.
   - Create a small analytics service wrapper under `lib/core` or `lib/data` that owns Firebase calls.
   - Gate collection by production environment, explicit developer override, and confirmed Analytics Preference.
   - Ensure sign-out and account deletion clear Firebase user association.
   - Do not enable automatic screen tracking.

5. Presentation preference UI:
   - Add an Analytics Preference Cubit or BLoC for loading/updating preference.
   - Add the Help Improve OnTime switch to My Page app settings near Privacy Policy.
   - Use English label `Help improve OnTime` and Korean label `OnTime 개선에 참여`.
   - Show loading/error behavior for preference fetch/update without silently assuming enabled.

6. Event tracking use case:
   - Add `TrackProductUsageEventUseCase` with validation against the event catalog.
   - Reject or strip forbidden fields, arbitrary maps, raw exceptions, and user-authored content.
   - Add common parameters including `schema_version`, `workflow`, `result`, `platform`, and `app_version`.

7. BLoC/Cubit instrumentation:
   - `OnboardingCubit`: emit `onboarding_completed` after onboarding succeeds.
   - Auth/sign-in flows: emit `sign_up_completed` and `login_completed` after successful auth by provider.
   - `ScheduleFormBloc`: emit `schedule_create_started`, `schedule_created`, and `schedule_updated` at confirmed workflow boundaries.
   - Schedule deletion: emit `schedule_deleted` only after there is a BLoC or use-case success boundary.
   - Notification permission flow: emit `notification_permission_result` after permission flow resolves.
   - Alarm launch/status flow: emit `alarm_opened` and `alarm_failed` from stable alarm workflow boundaries.
   - `ScheduleBloc`: emit `schedule_finished` after finish succeeds.

8. Tests:
   - Unit-test preference repository/use cases for local-only, account-loaded, conflict, update failure, and load failure behavior.
   - Unit-test analytics wrapper gating for production, debug, disabled preference, unknown preference, sign-out, and account deletion.
   - Unit-test `TrackProductUsageEventUseCase` to enforce allowed parameters and forbidden-field rejection.
   - Add BLoC/Cubit tests for each implemented milestone emission.
   - Add My Page widget tests for the Help Improve OnTime switch, loading state, update success, and update failure.

9. Rollout:
   - Keep provider collection disabled until backend API, privacy docs, Play Data Safety docs, and tests are complete.
   - Run `flutter analyze`.
   - Run focused analytics tests, then `flutter test`.
   - Re-run Google Play release checklist items that mention analytics, diagnostics, SDK providers, privacy policy, and Data Safety.

## Validation

- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs` if generated models or Injectable wiring change.
- `flutter analyze`
- Focused tests for analytics preference, analytics tracking, My Page toggle, and instrumented BLoCs/Cubits.
- `flutter test`
- Manual My Page smoke test for preference load, toggle on/off, failed update, sign-out, and account deletion behavior.
- Documentation review confirms `docs/Privacy-Policy-Draft.md`, `docs/Google-Play-Data-Safety.md`, and release checklist evidence match the shipped Firebase Analytics behavior.

## Open Questions

- Backend delivery branch is not assigned yet; backend issue is DevKor-github/OnTime-back#318.
- Backend-hosted privacy policy update is tracked by DevKor-github/OnTime-back#319 and should be handed over during the Firebase Analytics release.
- Final Firebase console settings owner must confirm whether any Analytics-linked exports or Google integrations are enabled.
- Production gating mechanism needs a concrete implementation choice, such as existing flavor/build mode checks or a Dart define.
- Stable error categories beyond `alarm_failed` are intentionally deferred.
