# Issue 453: Lock Initial Production Versioning

## Scope

- Confirm the first production public version name and build suffix.
- Keep `pubspec.yaml` as the source of truth for the checked-in Flutter app version.
- Document how Android Play derives the production `versionCode` for CI uploads.
- Document the future bump rule for public releases.

## Files

- `pubspec.yaml`: already set to `version: 1.0.0+1`; no change needed.
- `docs/Release-Checklist.md`: clarify the initial versioning decision and future bump rule.

## Implementation Approach

- Treat `1.0.0` as the initial production `versionName`.
- Treat the checked-in Flutter build suffix `+1` as the initial local/manual build number.
- Keep Android Play CI uploads on `github.run_number` for the generated Android `versionCode`.
- Avoid changing release signing, Firebase configuration, Play Console setup, or build workflows.

## Verification

- Confirm `pubspec.yaml` still declares `version: 1.0.0+1`.
- Confirm the release checklist documents the initial version name, initial build suffix, Android CI `versionCode`, and future bump rule.
- Run `flutter analyze`.

## Blockers

- None. This issue does not require Play Console access or signing secrets.
