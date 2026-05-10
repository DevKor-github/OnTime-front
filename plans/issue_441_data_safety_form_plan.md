# Issue 441 Data Safety Form Plan

Parent track: #464
Issue: #441 - Complete Google Play Data safety form
Status: Data safety and privacy policy URL saved; app-content submission externally blocked
Prepared: 2026-05-10

## Decision

The Google Play Data safety questionnaire has been completed and saved in Play
Console, and the hosted privacy policy URL has been saved in the Privacy Policy
page. Do not mark the broader app-content submission complete from this repo
thread because Play Console still requires target audience/content before
release review can proceed.

Repo-side work now preserves the source-backed worksheet and the Play Console
answers that were saved on 2026-05-10.

## Current Prerequisite State

| Prerequisite | Current state | Impact on #441 |
| --- | --- | --- |
| #434/#435/#437 privacy policy text and hosting | Hosted and entered; #434 approval still open | Public URL is `https://ontime-back.duckdns.org/privacy-policy`; product/legal approval of final text remains tracked by #434. |
| #439 backend deletion/retention behavior | Closed with static backend evidence | Deletion support and retention language are documented; production retention enforcement still needs owner confirmation before final submission. |
| #440 external deletion request URL | Closed | Delete account URL is saved in the Play Console Data safety draft. |
| #442 manifest permission audit | Closed | Permission evidence is available in `docs/Android-Manifest-Permissions.md`. |
| Target audience and content | Open in Play Console | Play Console preview blocks submission until target age group and related content information are completed. |
| Final SDK/provider decision | Not recorded as complete | Active release auth and SDK set must be confirmed before submission. |

## Implementation Scope

1. Create `docs/Google-Play-Data-Safety.md` as the Data safety worksheet and
   saved-answer record.
2. Record source-backed data flow evidence from the current Flutter app.
3. Enter the Data safety questionnaire in Play Console and save the draft.
4. Record the saved Play Console answers in the worksheet.
5. Do not change app behavior, privacy copy, or SDK usage.

## Verification

- Confirm Play Console preview shows the Data safety answers and saved state.
- Confirm the broader app-content submission remains blocked until target
  audience/content is complete.
- Run markdown/source checks that prove the new worksheet and links exist.
- Do not run Flutter tests for this docs-only change unless Dart code changes.

## Remaining Human Tasks

1. Backend/environment owner must confirm production retention settings, backup
   rotation, and cleanup jobs match the documented retention periods.
2. Product/legal owner must approve privacy policy text and ensure it matches
   backend behavior.
3. Release owner must keep the hosted privacy policy URL stable:
   `https://ontime-back.duckdns.org/privacy-policy`.
4. Release owner must confirm the active release SDK/provider set.
5. Play Console owner must send saved app-content changes for review from
   Publishing overview after the remaining blockers are complete.
