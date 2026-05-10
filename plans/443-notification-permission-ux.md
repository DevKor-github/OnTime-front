# Issue #443: Verify Notification Permission UX

Parent track: #465 Android permissions and alarm policy

## Status

#443 is codex-ready. It has no prerequisites and is scoped to notification permission UX only.

## Scope

- Ensure pre-permission/contextual copy explains notifications support schedule preparation and reminders.
- Cover Android 13+ style runtime permission outcomes in code-level tests where practical:
  - already granted
  - first request granted
  - request denied
  - denied/settings recovery
- Check Korean and English strings.

## Likely Files

- `lib/presentation/notification_allow/screens/notification_allow_screen.dart`
- `lib/presentation/my_page/my_page_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_ko.arb`
- generated localization files under `lib/l10n/`
- new or updated widget tests under `test/presentation/notification_allow/`

## Implementation Approach

- Keep existing permission routing and notification gate behavior.
- Update the onboarding notification permission rationale copy and settings-recovery copy in both English and Korean to explicitly mention schedule preparation/reminders.
- Make the notification allow screen permission handler testable through a small injectable abstraction, without changing app behavior.
- Add focused widget tests for granted, denied, settings-open, and localized copy paths.

## Verification

- `flutter gen-l10n`
- `dart format lib test`
- targeted widget tests for notification permission UX
- `flutter analyze`

## Left Out

- Exact alarm permission UX (#444).
- Android manifest permission audit (#442).
- Full-screen intent declaration (#445).
- Device-level alarm/notification QA (#457).
