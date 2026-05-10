# Issue 460 Content Category and UGC Audit Plan

## Goal

Confirm whether the current OnTime release exposes user-created content to other
users, document the release checklist result, and confirm the app is not in a
restricted content category before Play submission.

## Context

- Parent release track: #466, Store listing and content.
- Sub-issue: #460, Audit content category and UGC exposure.
- #460 is labeled `codex-ready`, has no prerequisites, and asks for a scoped
  audit only.
- The source issue references `plans/release_app_todos.md`, but that file is not
  present in this checkout.
- Current app scope from `README.md` and `pubspec.yaml`: schedule preparation,
  alarms, reminders, and arrival-time planning.
- Audited endpoint and data-source surfaces include authentication, user profile,
  feedback, schedules, preparations, FCM token registration, alarm settings,
  device registration, alarm windows, and alarm status reporting.

## Decisions

- Treat this as a documentation and release-readiness audit, not a product-code
  change. No app behavior is required when the audit finds no UGC exposure.
- Use `docs/Release-Checklist.md` as the release checklist artifact requested by
  the acceptance criteria.
- Do not create report, block, or moderation issues unless the audit finds
  user-created content visible to other users.
- Keep restricted-category confirmation limited to the current repository
  surface; future feature work must re-audit before store submission.

## Steps

1. Inspect #466 and #460 metadata, labels, prerequisites, and comments.
2. Confirm the active branch is `codexd/460-audit-content-category-ugc`.
3. Audit source endpoints, remote data sources, entities, and public docs for
   social sharing, public profiles, feeds, comments, chat, uploads, report/block
   controls, and restricted-category signals.
4. Update `docs/Release-Checklist.md` with the current no-UGC result,
   restricted-category result, and explicit re-audit requirements.
5. Review the diff and verify the added documentation answers each #460
   acceptance criterion.
6. Commit only #460-related files, push the branch, and open a draft PR that
   closes #460 and references #466.

## Validation

- `git diff --check`
- `git diff -- docs/Release-Checklist.md plans/460-audit-content-category-ugc-plan.md`
- Source audit searches over `lib`, `docs`, `README.md`, and `pubspec.yaml` for
  UGC, sharing, moderation, and restricted-category terms.

## Open Questions

None. Human Play Console category selection still needs normal release-owner
confirmation during store submission, but it does not block documenting this
repository audit.
