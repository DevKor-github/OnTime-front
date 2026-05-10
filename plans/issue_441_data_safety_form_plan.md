# Issue 441 Data Safety Form Plan

Parent track: #464
Issue: #441 - Complete Google Play Data safety form
Status: externally blocked
Prepared: 2026-05-10

## Decision

Do not submit or mark #441 complete from this repo thread. The issue is blocked
by unresolved human/backend/Play Console inputs that directly affect the
answers in the Google Play Data safety form.

Repo-side work can still advance #441 by preserving a source-backed worksheet
that release owners can use once the prerequisites are resolved.

## Current Prerequisite State

| Prerequisite | Current state | Impact on #441 |
| --- | --- | --- |
| #434 privacy policy text | Open, manual | Final Data safety answers cannot be checked for consistency. |
| #439 backend deletion/retention behavior | Open, manual/backend | Deletion support, retention exceptions, and collected data inventory are not final. |
| #440 external deletion request URL | Open, manual | The Data safety deletion mechanism answer and Play account deletion fields are not final. |
| #442 manifest permission audit | Closed | Permission evidence is available in `docs/Android-Manifest-Permissions.md`. |
| Final SDK/provider decision | Not recorded as complete | Active release auth and SDK set must be confirmed before submission. |

## Implementation Scope

1. Create `docs/Google-Play-Data-Safety.md` as a worksheet, not a final
   declaration.
2. Record source-backed data flow evidence from the current Flutter app.
3. Mark all answers that require backend owner, product/legal owner, or Play
   Console access as pending.
4. Link the worksheet from the docs index and release checklist so future
   release work can find it.
5. Do not change app behavior, privacy copy, SDK usage, or Play Console state.

## Verification

- Confirm #441 remains open and blocked until the external prerequisites are
  complete.
- Run markdown/source checks that prove the new worksheet and links exist.
- Do not run Flutter tests for this docs-only change unless Dart code changes.

## Remaining Human Tasks

1. Backend owner must verify deletion and retention behavior for normal, Google,
   and Apple account paths.
2. Product/legal owner must approve privacy policy text and ensure it matches
   backend behavior.
3. Release owner must host the approved privacy policy and account deletion page
   at public HTTPS URLs.
4. Release owner must confirm the active release SDK/provider set.
5. Play Console owner must enter and submit the final Data safety form.
