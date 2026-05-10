# Issue 448 Play Listing Graphics Plan

## Goal

Prepare the repo-side checklist and verification path for Play listing graphics
under release issue #448 and parent track #466.

## Context

- Parent issue #466 orders this after #446 app identity and #447 Play listing
  copy.
- Issue #448 is labeled `manual`.
- #446 is closed and confirms the public app name is `OnTime` and Android
  application ID is `club.devkor.ontime`.
- #447 is closed and adds `docs/Google-Play-Listing-Copy.md` as the listing
  copy source.
- Current launcher source is `assets/icons/app_icon.png`, and
  `flutter_launcher_icons.yaml` generates Android launcher icons from that
  source with adaptive background `#5C79FB`.

## Decisions

- Treat final graphic production and Play Console upload as external manual
  work because the issue requires final design/product assets or design-owner
  input.
- Do not fabricate feature graphics, screenshots, or Play Console assets.
- Provide a checklist that names the current Google Play size and format
  requirements checked on 2026-05-10, the repo launcher-icon source of truth,
  and the consistency checks a human must run before submission.
- Keep release screenshots out of scope except to point to #449, because that
  sub-issue owns capturing real release screenshots.

## Steps

1. Inspect #466 and #448 metadata, labels, prerequisites, and comments.
2. Confirm the active branch is `codexd/448-play-listing-graphics`.
3. Review current launcher icon configuration and generated Android icon files.
4. Confirm current Play listing graphic requirements from official Google Play
   documentation.
5. Add a scoped Play listing graphics checklist under `docs/`.
6. Link the checklist from `docs/Release-Checklist.md`.
7. Verify the documentation diff and commit only #448-related files.

## Validation

- `git diff --check`
- `sips -g pixelWidth -g pixelHeight -g hasAlpha assets/icons/app_icon.png web/icons/Icon-512.png web/icons/Icon-192.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Manual review of `docs/Google-Play-Listing-Graphics.md` against #448
  acceptance criteria.

## Blockers

- Final feature graphic and listing art require design-owner approval.
- Play Console upload and visual comparison require human Play Console access.
- Screenshot capture remains covered by #449.
