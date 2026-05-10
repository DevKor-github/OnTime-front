# Issue #436: In-App Privacy Policy Link Plan

## Status

Externally blocked as of 2026-05-10.

Issue #436 requires the final hosted privacy policy HTTPS URL. That URL is owned
by prerequisite issue #435, which is still open and depends on approved privacy
policy text from #434. #434 depends on backend deletion and retention truth from
#439. Do not implement a placeholder URL or close #436 until those prerequisites
are complete.

## Parent Track Context

Parent issue #464 orders the privacy/account-deletion work as:

1. #438 - in-app account deletion flow: closed.
2. #439 - backend account and data deletion behavior: open, manual.
3. #434 - draft and approve the privacy policy: open, manual.
4. #435 - host the privacy policy on a public HTTPS URL: open, manual.
5. #436 - add an in-app privacy policy link: open, blocked.

The next action for the track is to complete #439, then #434, then #435. Once
#435 records the final URL, #436 can be implemented and verified.

## Existing Repo Context

- My Page/settings UI lives in `lib/presentation/my_page/my_page_screen.dart`.
- The screen already has an app settings section with `_SettingTile` rows.
- `url_launcher` is already declared in `pubspec.yaml`.
- Localization source files are `lib/l10n/app_en.arb` and
  `lib/l10n/app_ko.arb`; generated files are committed under `lib/l10n/`.
- Existing My Page coverage is currently focused on account deletion modal tests
  in `test/presentation/my_page/delete_user_modal_test.dart`; there is no full
  `MyPageScreen` widget test yet.

## Decision-Complete Implementation Plan

Use this plan after #435 provides the final public HTTPS URL:

1. Add a single source of truth for the URL.
   - Preferred location: a small constant near other app constants, for example
     `lib/core/constants/legal_urls.dart`.
   - Store only the final `https://...` URL from #435.
   - Do not use staging, draft, document-edit, PDF, login-gated, or placeholder
     URLs.

2. Add localized labels.
   - Add `privacyPolicy` to `lib/l10n/app_en.arb` with value
     `Privacy Policy`.
   - Add `privacyPolicy` to `lib/l10n/app_ko.arb` with value
     `개인정보 처리방침`.
   - Run `flutter gen-l10n` so `app_localizations.dart`,
     `app_localizations_en.dart`, and `app_localizations_ko.dart` stay in sync.

3. Add the visible My Page entry.
   - In `lib/presentation/my_page/my_page_screen.dart`, add a `_SettingTile`
     for `AppLocalizations.of(context)!.privacyPolicy`.
   - Place it in the App Settings section unless product/design says it belongs
     under Account Settings.
   - Use `url_launcher` with `LaunchMode.externalApplication` so the link opens
     in a browser or system handler.
   - Fail gracefully if launch returns false or throws; do not crash the screen.

4. Add or update widget coverage.
   - Add a My Page widget test if practical, or a focused testable helper if the
     current screen dependencies make full pumping brittle.
   - Verify the localized entry is visible in Korean and English.
   - Verify tapping the entry attempts to launch exactly the final HTTPS URL.

5. Verify Android release behavior.
   - Run `flutter analyze`.
   - Run the new or updated widget test.
   - On an Android release-equivalent build, tap the My Page privacy policy
     entry and confirm it opens the final public HTTPS URL.

## Acceptance Evidence To Attach To #436 Or PR

- Final URL from #435.
- Screenshot or recording of the My Page entry.
- Android release-build result showing the URL opens.
- Test command output for analyzer and relevant widget tests.
