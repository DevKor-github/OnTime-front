# Issue 450 Release Signing Plan

Parent track: #467
Sub-issue: #450 - Configure release signing ownership and secrets

## Scope

- Document who owns the Android upload keystore and how it is stored without exposing secrets.
- Document the local and CI signing inputs used by Gradle.
- Ensure signing secret files are ignored by git.
- Verify that release signing failures are explicit when required inputs are missing.

## Files Likely Touched

- `.gitignore`
- `docs/Android-Release-Signing.md`
- `docs/Android-Signing-Setup.md`
- `plans/issue-450-release-signing.md`

## Implementation Approach

- Add git ignore rules for `android/key.properties`, keystores, and related signing artifacts.
- Tighten release signing docs to name the release owner role, storage process, local `key.properties` path, CI secret names, and failure behavior.
- Keep Firebase config, versioning, Play signing fingerprints, signed AAB production, and device smoke testing out of scope.

## Verification

- Review the diff for secret-free documentation only.
- Run `git check-ignore` against representative signing secret paths.
- Run a release Gradle validation task without signing inputs and confirm the error explains which signing inputs are missing.

## Blockers

- No blocker for documentation and Gradle validation.
- A human release owner still must create or confirm the real upload keystore and store the actual secrets in the team secret manager.

## Explicitly Left Out

- Creating a real keystore.
- Committing `android/key.properties`.
- Adding Firebase `google-services.json`.
- Building a signed AAB.
- Recording Play App Signing SHA-1/SHA-256 fingerprints.
