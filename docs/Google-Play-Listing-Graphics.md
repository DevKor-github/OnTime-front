# Google Play Listing Graphics

Checklist status: prepared for design/product completion before Play Console
upload.

This document covers release issue #448. It does not create final artwork. Use
it to brief the designer or release owner, validate exported assets, and confirm
that launcher and Play listing graphics stay consistent.

References checked on 2026-05-10:

- [Add preview assets to showcase your app - Play Console Help](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Metadata - Play Console Help](https://support.google.com/googleplay/android-developer/answer/9898842?hl=en)
- [Manage your store listing, experiment, and event graphics with the Asset Library - Play Console Help](https://support.google.com/googleplay/android-developer/answer/16386748?hl=en)

## Current Repo Source

- Public app name: `OnTime`.
- Android application ID: `club.devkor.ontime`.
- Launcher source image: `assets/icons/app_icon.png`.
- Launcher generation config: `flutter_launcher_icons.yaml`.
- Android adaptive icon background: `#5C79FB`.
- Generated Android launcher outputs:
  - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` - 48 x 48, alpha.
  - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` - 72 x 72, alpha.
  - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` - 96 x 96, alpha.
  - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` - 144 x 144, alpha.
  - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` - 192 x 192, alpha.

## Required Asset Package

Prepare these assets from the approved design source before opening the Play
Console main store listing.

| Asset | Required export | Current owner |
| --- | --- | --- |
| App icon | 512 x 512, 32-bit PNG with alpha, maximum 1024 KB | Design/release owner |
| Feature graphic | 1024 x 500, JPEG or 24-bit PNG with no alpha | Design/release owner |
| Phone screenshots | Owned by #449; minimum two screenshots, JPEG or 24-bit PNG with no alpha, each side 320-3840 px and long side no more than twice the short side | #449 owner |

For better Play recommendation eligibility, prepare at least four app
screenshots at 9:16 portrait 1080 x 1920 or 16:9 landscape 1920 x 1080. Final
screenshots must come from real release screens under #449.

## Visual Consistency Checklist

- Use the approved `OnTime` launcher mark for the Play app icon.
- Confirm the Play app icon and the installed Android launcher icon are the
  same brand mark, colors, and shape treatment. The Play icon can be higher
  fidelity, but it must not look like a different product.
- If `assets/icons/app_icon.png` changes, regenerate launcher icons before
  release:

```sh
flutter pub get
dart run flutter_launcher_icons
```

- Re-check generated Android icons in `android/app/src/main/res/mipmap-*` and
  `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.
- Keep the feature graphic visually related to the app icon and in-app style,
  but do not make it a large duplicate of the icon.
- Avoid fine details, tiny text, or edge-critical content in the feature
  graphic because Play surfaces may crop or scale it.
- Keep key feature graphic content near the center and background-only elements
  near the edges.
- Do not include store badges, ranking claims, promotional pricing, calls to
  action, unsupported features, or third-party marks without permission.
- Match claims to shipped functionality listed in
  `docs/Google-Play-Listing-Copy.md`.
- Provide Play Console alt text for the feature graphic and screenshots using
  concise descriptions of the actual content.

## Human Completion Steps

1. Get design/product approval for the final launcher mark and feature graphic.
2. Export the Play app icon and feature graphic in the required formats.
3. Capture final screenshots through #449.
4. Compare the uploaded Play app icon against an installed release build icon.
5. Confirm graphics do not imply unsupported features, social/UGC behavior,
   awards, rankings, discounts, or platform affiliations.
6. Upload approved assets in Play Console under
   `Grow users > Store presence > Main store listing`.
7. Store the final source design files and upload-ready exports in the team's
   agreed design or release asset location, and record that location in the
   release checklist or issue comment.

## Completion Evidence Template

Paste this into #448 after the human work is done:

```md
## Play listing graphics completion evidence

- Design source location:
- Upload-ready asset location:
- Play app icon: 512 x 512 PNG with alpha, <= 1024 KB: yes/no
- Feature graphic: 1024 x 500 JPEG or 24-bit PNG without alpha: yes/no
- Launcher icon consistency checked against installed release build: yes/no
- Screenshots supplied by #449: yes/no
- Unsupported feature / ranking / promotional claim review: pass/fail
- Play Console upload completed by:
- Date:
- Notes:
```
