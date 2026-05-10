# Issue #449 Release Screenshot Plan

Issue: [#449](https://github.com/DevKor-github/OnTime-front/issues/449)
Parent track: [#466](https://github.com/DevKor-github/OnTime-front/issues/466)

## Decision

Issue #449 is externally blocked for completion because final screenshots must
be captured from a release-like build on a device or release-equivalent
environment. The repo-side action that advances the issue is to provide a
capture checklist, Play asset constraints, required screen matrix, and evidence
log for the human/device capture pass.

## Ordered Work

1. Confirm parent-track state:
   #446, #447, and #460 are closed; #448 and #449 remain open manual items.
2. Confirm #449 scope:
   capture real release screenshots covering onboarding/permission, schedule
   creation, alarm/preparation, calendar/home, and My Page/account controls.
3. Add a repository guide:
   `docs/Google-Play-Release-Screenshots.md` documents setup, current Play
   constraints, capture matrix, quality review, and evidence log.
4. Link the guide from release docs:
   update `docs/Release-Checklist.md` and `docs/Home.md`.
5. Do not generate or fake screenshots:
   completion requires human/device access and Play Console validation.
6. Verify documentation only:
   run a markdown/reference smoke check and inspect git diff.

## Human Completion Criteria

- Capture screenshots from the release candidate or equivalent signed build.
- Validate every uploaded file in Play Console for format and dimensions.
- Have product/design approve the selected screenshot set.
- Update the evidence log with build, device, locale, filenames, reviewer, and
  upload result.
- Close #449 only after the actual screenshots are accepted for the listing.
