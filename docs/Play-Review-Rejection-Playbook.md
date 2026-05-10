# Play Review Rejection Playbook

Use this playbook when Google Play rejects an OnTime app submission or update.
It is scoped to Play review response only; release rollout monitoring belongs in
the release ownership checklist.

## Response Owner

- Assign a Play review monitor before each Play Console submission.
- Assign a backup monitor who has Play Console and policy email access.
- The monitor checks Play Console policy status and the developer account policy
  email inbox at least twice per business day while a release is in review.
- The monitor opens the response thread within one business hour after a
  rejection notice is found and records the intake checklist below.
- The monitor owns coordination until the release is resubmitted, appealed, or
  explicitly handed off.

## Immediate Triage

1. Stop any further Play Console submissions for the rejected app until the
   cited policy issue is understood and fixed.
2. Save the rejection email, Play Console policy status page, and affected
   release details in the release tracking thread.
3. Identify whether the status is an app rejection, update rejection, removal,
   suspension, or another enforcement action.
4. Confirm whether the previously published version remains available to users.
5. Notify the release owner, backup owner, and the engineer responsible for the
   affected release change.

## Rejection Intake Checklist

Record these details before changing code, store metadata, declarations, or the
appeal form:

- Rejection received date and time, including timezone.
- Play Console app status, update status, and affected item status.
- Affected package name, track, release name, version name, and version code.
- Rejection reason exactly as summarized by Google Play.
- Affected policy or Developer Distribution Agreement section.
- Reviewer notes, examples, and remediation instructions from the email or Play
  Console.
- Screenshots of the policy status page, review summary, affected declarations,
  and any highlighted store listing or in-app evidence.
- Submitted declarations that may relate to the rejection, including Data
  safety, content rating, target audience, permissions, ads, account deletion,
  health, financial, location, background activity, and notification
  disclosures.
- Store listing fields involved, including title, short description, full
  description, screenshots, feature graphic, privacy policy URL, support
  contact, and release notes.
- Build artifacts involved, including `.aab` filename, commit SHA, workflow run,
  signing source, Firebase config source, and Dart defines.
- Whether a previous production version remains available.
- Whether the same or similar rejection has happened before.
- Proposed owner for the fix and proposed deadline for the next response.

## Fix And Resubmit

Prefer fixing and resubmitting when any of these are true:

- The rejection identifies a real app behavior, metadata, declaration, or
  permissions mismatch.
- The submitted declarations are incomplete, stale, or inconsistent with the
  build.
- The store listing, screenshots, or release notes can be corrected without
  disputing Google's policy interpretation.
- The reviewer notes point to a reproducible issue in the submitted build.
- The team cannot prove the submitted build and metadata were policy-compliant
  at review time.

Before resubmission:

- Fix every cited policy issue and any nearby declaration or metadata mismatch.
- Review the same policy area across the whole app, not only the example cited
  in the notice.
- Update the intake thread with the exact changed files, Play Console fields, or
  declarations.
- Attach evidence for the fix, such as screenshots, test notes, or store listing
  diffs.
- Confirm the new build number is higher than the rejected upload when a new
  Android App Bundle is submitted.
- Ask the release owner or backup owner to approve resubmission.

## Appeal

Use an appeal only when the team has a factual reason to believe the enforcement
decision is incorrect or incomplete. Appeal when one of these is true:

- The rejected behavior is not present in the submitted build.
- Google Play appears to have reviewed stale metadata, stale declarations, or
  the wrong release item.
- The policy requirement is already satisfied and the team can provide precise
  evidence.
- The requested fix would make the app inaccurate, misleading, or nonfunctional.
- The enforcement action is more severe than the facts support and there is a
  clear record showing compliance.

Do not appeal only to ask for a faster review, to dispute policy without
evidence, or to avoid making a known compliance fix. If the team both fixes an
issue and appeals, state exactly what changed and what part of the decision is
still being disputed.

## Appeal Response Template

```text
Subject: Appeal for OnTime Google Play review decision

App: OnTime
Package name: club.devkor.ontime
Affected release: <track>, <version name>, <version code>
Decision received: <date and time with timezone>
Policy cited: <policy or DDA section named by Google Play>

Hello Google Play Review Team,

We are appealing the review decision for the OnTime release listed above because
<one-sentence factual reason the decision appears incorrect or incomplete>.

Facts:
- <Fact 1 tied to the submitted build, declaration, or store listing>
- <Fact 2 tied to reviewer notes or Play Console evidence>
- <Fact 3 tied to screenshots, policy text, or implemented behavior>

Fixes or verification completed:
- <Code, metadata, declaration, or test change completed, or "No change needed
  because ...">
- <Evidence location, screenshot name, workflow run, or test result>

Requested outcome:
Please re-review this release with the evidence above and reinstate approval if
you agree it complies with the cited policy.

Thank you.
```

## Evidence Folder Template

Use this structure in the release tracking thread or shared release folder:

```text
play-review-rejection-<version-code>/
  rejection-email.txt
  policy-status.png
  review-summary.png
  submitted-declarations/
  store-listing-before/
  store-listing-after/
  build-artifact.txt
  fix-summary.md
  appeal-response.txt
```

## References

- Google Play Console Help: Check your app's policy status
  https://support.google.com/googleplay/android-developer/answer/9842754
- Google Play Console Help: Publish your app
  https://support.google.com/googleplay/android-developer/answer/9859751
- Google Play Developer Program Policy: Enforcement process and enforcement
  actions
  https://play.google.com/about/developer-content-policy/
