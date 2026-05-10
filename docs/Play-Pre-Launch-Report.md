# Play Pre-Launch Report

Use this runbook after a signed Android App Bundle has been uploaded to Google
Play Internal Testing or Closed Testing. It is the release gate for issue #459.

## Prerequisites

- #452 is complete: a signed release AAB has been uploaded to an internal or
  closed testing track for `club.devkor.ontime`.
- The uploaded build uses the intended version name and Play `versionCode`.
- The release owner has Google Play Console access for the app.
- The release owner can file or assign follow-up issues for any blocking
  findings.

Do not close #459 before the actual Play Console report exists. Codex may help
triage exported report text, screenshots, or issue details, but cannot run the
report without Play Console access.

## Run The Report

1. Open Google Play Console for `club.devkor.ontime`.
2. Confirm the internal or closed testing release contains the intended AAB.
3. Open the release or testing track pre-launch report.
4. If the report has not finished, wait for completion before making the
   release decision.
5. Save the report URL or screenshots in the release tracking thread.
6. Record the devices, Android versions, locales, and test account state covered
   by the report when Play Console exposes them.

## Triage Expectations

Treat these as release-blocking unless the release owner explicitly accepts the
risk in writing:

- Crash on launch, login, notification permission flow, schedule creation,
  schedule edit/delete, My Page, or privacy policy navigation.
- ANR during startup, authentication, schedule/preparation flows, notification
  prompts, or alarm-related flows.
- Policy warning, app content warning, SDK warning, permission warning, or
  Play account warning tied to the uploaded build.
- Severe accessibility finding that prevents core navigation, authentication,
  schedule management, or required disclosure access.
- Device-specific failure on a common Android version or device profile that is
  likely to affect real testers.

Non-blocking findings still need a recorded owner decision. Prefer follow-up
issues for cosmetic accessibility warnings, device-specific rendering glitches,
or low-risk warnings that do not prevent internal testing.

## Evidence Template

Use this template in the release tracking thread, PR, or issue comment before
closing #459:

```md
Pre-launch report evidence

App:
Package:
Track:
Version name:
Version code:
AAB source:
Play Console report URL:
Report completed at:
Release owner:

Summary:
- Crashes:
- ANRs:
- Policy/app content warnings:
- Severe accessibility warnings:
- Device or OS-specific failures:

Blocking findings:
- None / <link issue, owner, and decision>

Accepted risks:
- None / <finding, reason, owner approval>

Follow-up issues:
- None / <issue links>

Release decision:
- Continue internal testing / hold release / upload fixed build
```

## Closure Checklist

- The report completed for the intended uploaded build.
- Crashes and ANRs are reviewed.
- Policy and app content warnings are reviewed.
- Severe accessibility warnings are reviewed.
- Release-blocking findings are fixed in a new build or explicitly accepted by
  the release owner.
- Evidence is recorded in the release tracking thread or #459.
