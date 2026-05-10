# Google Play Release Screenshots

Use this checklist to capture the Play Store screenshots for issue #449. The
final screenshots must come from a release-like app build on a real device or
release-equivalent emulator; do not use mock-only screens, Widgetbook states, or
debug-only data.

Last checked against Google Play Console Help on 2026-05-10:

- [Add preview assets to showcase your app](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en-EN)
- [Store listing practices](https://support.google.com/googleplay/android-developer/answer/13393723?hl=en)

## Capture Setup

- Build and install the release candidate that will be submitted, or an
  equivalent signed build from the same commit and environment.
- Use the shipped localization that the screenshot will represent. If the
  listing has Korean and English localized screenshots, capture each language
  separately.
- Use realistic but non-sensitive sample data. Do not show personal names,
  private addresses, phone numbers, access tokens, backend IDs, or real user
  accounts.
- Clear unrelated system notifications before capture. Keep the device status
  bar clean and plausible.
- Keep the app name, icon, and visible copy consistent with `OnTime` and
  `docs/Google-Play-Listing-Copy.md`.

## Play Asset Constraints

Confirm current Play Console requirements again at upload time. As of the last
check above, screenshots must satisfy:

- At least 2 screenshots across device types are required to publish the store
  listing.
- Up to 8 screenshots can be uploaded for each supported device type.
- Accepted formats are JPEG or 24-bit PNG with no alpha channel.
- Each screenshot must have a minimum dimension of 320 px and a maximum
  dimension of 3840 px.
- The longest side cannot be more than twice the shortest side.
- For app recommendation eligibility, provide at least 4 app screenshots at
  minimum 1080 px resolution. Portrait screenshots should be 9:16, with
  1080 x 1920 px or higher.

## Required Capture Set

Capture at least these five app states. If the Play Console or product/design
owner wants fewer uploads, keep these as the source set and select the best
ordered subset after review.

| Order | App state | Route or flow | Capture requirements |
| --- | --- | --- | --- |
| 1 | Onboarding or permission request | `/onboarding/start`, `/onboarding`, or `/allowNotification` | Show the actual first-run setup or notification permission explanation. The text must match shipped localization. |
| 2 | Schedule creation | `/scheduleCreate` | Show a realistic appointment being created with date, time, place, travel time, spare time, and preparation steps where possible. |
| 3 | Alarm and preparation flow | `/scheduleStart` and `/alarmScreen` | Show the early-start prompt or active preparation checklist/timer for a real schedule. Do not fake alarm state with debug-only overlays. |
| 4 | Calendar or Home | `/home` or `/calendar` | Show upcoming schedules on Home or the monthly calendar with realistic non-sensitive schedule names. |
| 5 | My Page and account controls | `/myPage` | Show account/settings controls, including notification or default preparation settings if available. Avoid exposing a real email address. |

Optional additional screenshots:

- Preparation completion or early/late result at `/earlyLate`.
- Default preparation and spare time settings at
  `/defaultPreparationSpareTimeEdit`.
- Schedule edit flow at `/scheduleEdit/:scheduleId`.

## Quality Review

- Confirm every screenshot reflects the release candidate behavior.
- Confirm text, dates, and labels match the shipped localization.
- Confirm screenshots do not imply unsupported sharing, collaboration,
  location-tracking, map navigation, or other features not present in the app.
- Confirm screenshots do not contain debugging UI, emulator overlays, test
  banners, unfinished placeholders, or mock-only copy.
- Confirm image dimensions and file formats are accepted by Play Console before
  marking issue #449 complete.
- Record the build commit, build variant, device model, OS version, locale,
  screenshot filenames, and reviewer in the evidence log below.

## Evidence Log

Complete this table when screenshots are captured.

| Field | Value |
| --- | --- |
| Build commit | |
| Build variant | |
| Device or emulator | |
| Android version | |
| Locale(s) | |
| Screenshot filenames | |
| Dimension check result | |
| Product/design reviewer | |
| Play Console upload result | |
| Notes or follow-up issues | |
