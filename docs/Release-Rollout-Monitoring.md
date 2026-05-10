# Release Rollout Monitoring

Use this checklist after a Play Console submission is ready for review or a
release has been approved for tester or production rollout. It assigns release
ownership, defines rollout gates, and lists the signals the team must watch
before widening availability.

## Ownership

- Release owner: assign one engineer before submission. This person owns Play
  Console status checks, rollout decisions, incident coordination, and final
  go/no-go notes.
- Backup owner: assign one alternate before submission. This person must have
  access to the same dashboards and can pause rollout or coordinate rollback if
  the release owner is unavailable.
- Handoff channel: record the owner, backup, release version, build number,
  release track, and expected monitoring windows in the team release channel or
  shared release note.
- Required access: both owners need Google Play Console access, Firebase console
  access for the `ontime-c63f1` project, GitHub Actions access, and access to
  production backend logs or dashboards.

## Rollout Stages

1. Internal testing
   - Upload the signed AAB to Play Internal Testing as a draft release.
   - Confirm install, login, notification permission flow, Firebase
     initialization, FCM token registration, and the highest-risk user flows on
     at least one real Android device.
   - Do not proceed if install fails, Firebase initialization fails, login is
     broken, or the backend receives no token registration for a fresh install.
2. Closed testing or limited tester rollout
   - Release to the agreed tester group after internal testing is clear.
   - Hold for at least one active test pass or one business day, whichever is
     more useful for the release risk.
   - Do not proceed if testers report launch blockers, sign-in blockers, alarm
     delivery regressions, or data-loss behavior.
3. Production staged rollout
   - Start with the smallest practical Play production percentage.
   - Increase only after the first 24-hour checks are clean and no policy,
     crash, ANR, backend, or review signal suggests a release-caused regression.
   - Record every percentage increase with timestamp, owner, build number, and
     the dashboards checked.
4. Full rollout
   - Move to full rollout only after the first 7-day checks are clean or the
     release owner explicitly accepts the remaining known risk.
   - Keep monitoring for one additional business day after reaching 100%.

## Pause And Rollback Criteria

Pause the rollout immediately when any of these signals appear release-caused:

- Play Console review rejection, policy warning, app content warning, or account
  email requiring action.
- Crash rate or ANR rate materially above the previous production baseline.
- Repeated startup, login, schedule creation, notification, alarm, or token
  registration failures from testers or monitoring.
- Backend error spikes for authentication, schedule, preparation, alarm, or FCM
  token endpoints after the new build reaches users.
- Ratings or reviews identify a reproducible blocker in the new version.
- Support or team reports indicate data loss, missed alarms, broken sign-in, or
  privacy-sensitive behavior.

Rollback or supersede the release when pausing is not enough:

- If the issue is server-side and a backend fix can safely restore behavior,
  deploy the backend fix and keep the mobile rollout paused until metrics
  recover.
- If the issue is client-side and affects already-updated users, prepare a new
  fixed build and keep rollout paused until it is approved.
- If Play Console allows halting the staged rollout before wide exposure, halt
  it and document the affected percentage and build number.
- If a policy issue caused rejection or removal risk, follow the rejection
  response playbook from #461 once available and do not resubmit until the facts,
  fix, and declarations are aligned.

## Monitoring Locations

- Play Console review status: check the release status, publishing overview, app
  content warnings, policy status, release notes, and tester or production track
  rollout percentage.
- Play Console Android Vitals: monitor crash rate, user-perceived crash rate,
  ANR rate, excessive wakeups, battery, and device-specific clusters.
- Play Store ratings and reviews: watch new public reviews, tester feedback, and
  low-rating comments that mention the current version or rollout date.
- Policy email: monitor the Google Play developer account inbox and any team
  forwarding address for rejection, declaration, data safety, or policy notices.
- Firebase console: check Cloud Messaging delivery health and any crash or event
  dashboard the project has enabled for `ontime-c63f1`.
- GitHub Actions: confirm the release workflow artifact, generated build number,
  and deploy job match the build that reached Play Console.
- Backend monitoring: check production API logs and dashboards for elevated
  status codes, latency, authentication failures, schedule/preparation failures,
  alarm status report failures, and FCM token registration failures.
- Team channels and support inbox: watch for tester reports, screenshots, device
  details, and reproduction steps.

## First 24 Hours

- At submission: record version name, generated build number, track, rollout
  percentage, release owner, backup owner, and expected next check time.
- Every 2 to 4 hours during local business hours: check Play review status,
  policy email, Android Vitals, Firebase health, backend errors, and team
  reports.
- After approval or rollout start: verify installs from the active track and run
  a smoke test on a real Android device.
- Before any percentage increase: compare crashes, ANRs, backend errors, and
  tester or review feedback against the pre-rollout baseline.
- End of day: post a short status note with current rollout percentage, checked
  dashboards, issues found, and the next planned decision.

## First 7 Days

- Check Play Console, policy email, Android Vitals, reviews, Firebase, and
  backend dashboards at least once per business day.
- Track whether crash and ANR clusters are new, increasing, or tied to a
  specific device, OS version, or app version.
- Review low-rating feedback and tester reports for repeated symptoms before
  widening rollout.
- Confirm backend errors and latency remain stable for schedule, preparation,
  alarm, auth, and FCM token endpoints.
- Record each rollout increase with the reason it is acceptable and the signals
  checked.
- After reaching full rollout, keep one final next-business-day monitoring pass
  before closing the release monitoring note.

## Release Monitoring Note Template

```md
Release:
Build:
Track:
Current rollout percentage:
Release owner:
Backup owner:
Last checked:
Next check:

Signals checked:
- Play review/policy:
- Android Vitals crashes/ANRs:
- Ratings/reviews/tester feedback:
- Firebase/FCM:
- Backend errors/latency:
- Team/support reports:

Decision:
- Continue / pause / rollback / supersede

Notes:
```
