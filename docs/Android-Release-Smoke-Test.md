# Android Release Smoke Test

Use this runbook for the release-device smoke test tracked by #456. It must be
run against a signed release build installed through Google Play Internal
Testing or another release-equivalent install path after #452 has produced the
installable artifact.

Do not close #456 from documentation alone. Close it only after a human tester
records a completed pass with device, build, endpoint, and result evidence.

## Entry Criteria

- #452 is complete and the signed Android release build is available.
- The tested build uses package `club.devkor.ontime`.
- The build was installed from Play Internal Testing, a Play-generated APK set,
  or an equivalent signed release install path agreed by the release owner.
- The tester has a real Android device, a test account, and access to the
  release API/backend signal needed to confirm endpoint and token behavior.
- The release owner has confirmed which API base URL is approved for the smoke
  test, such as the staging URL for internal testing or the production URL for a
  tagged production candidate.

## Build And Device Evidence

Record this before testing:

```md
Issue: #456
Parent track: #467
Tester:
Date:
Install source: Play Internal Testing / signed release APK / other:
Artifact or Play release link:
Package name:
Version name:
Version code:
Git commit or workflow run:
ENV dart define:
REST_API_URL value or approved endpoint name:
Firebase project:
Device model:
Android version:
Network:
Fresh install: yes / no
Existing app data cleared before test: yes / no
```

## Required Smoke Pass

Mark each result `pass`, `fail`, or `blocked`. Attach screenshots, screen
recordings, logs, backend request IDs, or Play/Firebase evidence for failures
and for any endpoint verification that cannot be inferred from the app UI.

| Area | Steps | Expected result | Result | Evidence |
| --- | --- | --- | --- | --- |
| Install | Install the signed release build from the approved release-equivalent path. | App installs without sideload, signing, package, or Play Protect errors. | | |
| First launch | Launch the app from a fresh install. | App opens without a crash, blank screen, Firebase init error, or missing config error. | | |
| Login | Sign in with the test account using the release build. | Login succeeds and lands on the expected authenticated screen. | | |
| Endpoint | Confirm the build is using the approved release API endpoint. | Backend logs, request IDs, or app configuration evidence match the approved endpoint. | | |
| FCM token | Confirm fresh install token registration reaches the backend if backend access is available. | Backend receives token registration for the tested account/device. | | |
| Schedule create | Create a schedule with a place, moving time, preparation, and future start time. | The schedule is saved and visible in the app. | | |
| Schedule edit | Edit the created schedule. | Updated values persist after returning to the schedule list/detail. | | |
| Schedule delete | Delete the created schedule. | The schedule is removed and does not reappear after refresh or app restart. | | |
| My Page | Open My Page and review visible account/settings content. | Screen loads without release-only errors and expected content is present. | | |
| Privacy policy | Open the privacy policy link from the app. | The link opens the approved privacy policy URL without a broken or placeholder page. | | |
| Logout | Log out, then relaunch the app. | Session is cleared and the app returns to the signed-out flow. | | |
| Relaunch | Force close and reopen after the smoke flow. | App starts cleanly and remains in the expected auth state. | | |

## Failure Notes

For every failed or blocked row, record:

```md
Area:
Observed behavior:
Expected behavior:
Reproduction steps:
Device and Android version:
Version name and version code:
Timestamp with timezone:
Screenshots or recording:
Relevant logs:
Backend request ID or dashboard link:
Decision: retest after fix / accept risk / block release
Owner:
```

## Completion Note Template

Post a completion note on #456 with this structure:

```md
Android release smoke test result: pass / failed / blocked

Build:
- Version name:
- Version code:
- Commit or workflow run:
- Install source:
- Artifact or Play release link:
- ENV:
- REST_API_URL value or approved endpoint name:

Device:
- Model:
- Android version:
- Network:

Results:
- Install:
- First launch:
- Login:
- Endpoint verification:
- FCM token registration:
- Schedule create/edit/delete:
- My Page:
- Privacy policy link:
- Logout:
- Relaunch:

Issues found:
- None, or link issue numbers with reproduction notes.

Evidence:
- Screenshots/recordings/log links:
- Backend/Play/Firebase evidence:
```
