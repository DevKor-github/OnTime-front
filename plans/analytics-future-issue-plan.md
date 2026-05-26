# Analytics Future Work Issue Plan

## Goal

Create one consolidated, issue-ready task list for future analytics improvements after the initial analytics preference and `schedule_created` tracking foundation.

## Context

- Initial frontend analytics implementation is in PR #517.
- GitHub tracking issue: DevKor-github/OnTime-front#518.
- Current analytics collection is gated by `ONTIME_ANALYTICS_ENABLED` and confirmed Analytics Preference.
- Account preference behavior is documented in `docs/Analytics-Preference-API.md`.
- Current event names, common parameters, allowlists, and forbidden fields are documented in `docs/Analytics-Event-Catalog.md`.
- ADRs in `docs/adr/` constrain future work:
  - Track workflow milestone events, not raw taps or automatic screen views.
  - Emit from feature BLoCs/Cubits through an injected tracking use case.
  - Keep analytics parameters allowlisted and free of user-authored content, identifiers, raw exceptions, request bodies, and response bodies.
  - Defer Remote Config/experimentation until a concrete experiment exists.

## Decisions

- Use one tracking issue for the next analytics improvement batch instead of separate issues per event.
- Keep this issue limited to privacy-safe product analytics; marketing, personalization, and experimentation require explicit approval before implementation.
- Prioritize event schema validation before broadening event coverage so future instrumentation cannot drift from the catalog.
- Treat dashboards and QA tooling as part of the analytics feature, not optional polish, because they determine whether collected events are usable.

## Issue Draft

Title: Expand privacy-safe analytics coverage and validation

Body:

```markdown
## Goal

Expand OnTime analytics beyond the initial preference flow and `schedule_created` event, while preserving the current privacy boundaries and opt-out behavior.

## Scope

- Add event schema validation for all Product Usage Events.
- Add milestone event coverage for core product workflows.
- Add analytics QA/debug tooling for release verification.
- Define dashboard metrics that answer product questions.
- Prepare future experimentation only after a concrete experiment is approved.

## Tasks

- [ ] Add event catalog validation in `TrackProductUsageEventUseCase`.
  - [ ] Reject unknown event names.
  - [ ] Reject parameters not allowlisted for the event.
  - [ ] Reject forbidden value types such as arbitrary maps, raw exceptions, stack traces, request bodies, response bodies, and user-authored free text.
  - [ ] Keep common parameters: `schema_version`, `workflow`, `result`, `platform`, `app_version`.

- [ ] Expand schedule workflow events.
  - [ ] Track `schedule_create_started` when the create form initializes.
  - [ ] Track `schedule_updated` after schedule update succeeds.
  - [ ] Track `schedule_deleted` after deletion succeeds at a stable BLoC or use-case boundary.
  - [ ] Add tests proving analytics failures do not block schedule workflows.

- [ ] Expand onboarding and auth events.
  - [ ] Track `onboarding_completed` after onboarding succeeds.
  - [ ] Track `sign_up_completed` after successful sign-up.
  - [ ] Track `login_completed` after successful sign-in.
  - [ ] Use only coarse provider/category parameters, never account identifiers.

- [ ] Expand notification and alarm events.
  - [ ] Track `notification_permission_result` after the permission flow resolves.
  - [ ] Track `alarm_opened` when an alarm launch payload opens a schedule route.
  - [ ] Track `alarm_failed` only with stable, allowlisted error categories.
  - [ ] Track `schedule_finished` after schedule finish succeeds.

- [ ] Add analytics preference event coverage.
  - [ ] Track `analytics_preference_changed` only after a preference update succeeds.
  - [ ] Do not emit the event when signed-in account preference update fails.
  - [ ] Ensure disabling analytics stops future optional Product Usage Events.

- [ ] Add analytics QA/debug support.
  - [ ] Add a dev-only way to inspect emitted event names and parameters without waiting for Firebase Console propagation.
  - [ ] Keep QA logging disabled from production analytics payloads.
  - [ ] Document manual smoke steps for opt-in, opt-out, sign-out, and failed preference load.

- [ ] Define dashboards and product questions.
  - [ ] Define schedule creation rate.
  - [ ] Define onboarding completion rate.
  - [ ] Define notification permission grant rate.
  - [ ] Define alarm open and failure rates.
  - [ ] Define preparation completion / schedule finish rate.
  - [ ] Define analytics opt-in or enabled-rate reporting.

- [ ] Prepare experimentation only when approved.
  - [ ] Identify one concrete experiment candidate before adding Remote Config.
  - [ ] Document experiment hypothesis, audience, metrics, rollback, and privacy impact.
  - [ ] Keep experimentation out of scope until approved.

## Privacy Requirements

- Do not collect email, display name, OAuth ID, FCM token, access token, refresh token, schedule names, schedule notes, place names, preparation step names, request bodies, response bodies, raw exception strings, stack traces, or free text.
- Do not add automatic screen tracking.
- Do not add marketing or personalization events without separate approval.
- Keep analytics disabled when preference state is unknown or load failed.

## Validation

- `flutter analyze`
- Focused tests for event catalog validation.
- Focused BLoC/Cubit tests for each new event.
- Focused tests proving analytics failures do not fail user workflows.
- My Page preference regression tests.
- `flutter test`

## Done

- All new events are documented in `docs/Analytics-Event-Catalog.md`.
- Every emitted event has a behavior test at the owning workflow boundary.
- Invalid event names and invalid parameters are rejected or dropped before reaching Firebase.
- Analytics collection still respects build gate and confirmed user preference.
- QA/debug instructions exist for verifying event emission.
```

## Steps

1. Create a GitHub issue from the issue draft above.
2. Implement event validation before adding additional instrumentation.
3. Add workflow event coverage in small PRs grouped by owning BLoC/Cubit.
4. Add QA/debug support once at least two workflows emit events.
5. Add dashboard definitions after event names and parameters are stable.
6. Defer experimentation work until a concrete experiment is approved.

## Validation

- Review the issue draft against `docs/Analytics-Event-Catalog.md` to confirm every named event is documented or intentionally added there.
- Review privacy requirements against `docs/Privacy-Policy-Draft.md` and `docs/Google-Play-Data-Safety.md` before implementation.
- During implementation, run `flutter analyze` and `flutter test`.

## Open Questions

- None for creating the issue. Concrete dashboard owners and experiment candidates can be assigned when the issue is scheduled.
