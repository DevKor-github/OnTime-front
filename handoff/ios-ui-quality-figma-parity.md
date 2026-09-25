# iOS UI quality / Figma parity handoff

Updated 2026-09-25. Work is based on refreshed `main` `c7184b2a`, merged at `64bc111d`. The canonical source is [OnTime Design System](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System); the old `GiDCK...` link is not the source. [Draft PR #596](https://github.com/DevKor-github/OnTime-front/pull/596) remains open for review; this handoff does not authorize merge or assert release readiness.

## Completed scope

- [The manifest](../docs/design/figma_code_map.yaml) passes strict validation: 21 routes contain 16 reviewed/five excluded defaults, and 58 variants contain 57 reviewed/one excluded state. There are **73 reviewed app entries and zero pending/in-progress entries**. Each reviewed entry has source/golden evidence or a documented shared-component mapping. Five route exclusions mean no current full-screen Figma source; the one variant exclusion is the OS-owned permission alert.
- Home/Calendar, original and recurring appointment forms, preparation editing/runtime, onboarding/permissions, recovery/reset, My Data dialogs, and privacy have source-backed review and focused tests. The six detailed reports and their source hashes/golden links are indexed in [the completion report](../docs/design/review/completion-20260925.md#evidence-index).
- The calendar's December-title/November-grid contradiction is resolved as a documented source exception: runtime retains correct dates. Other explicit adaptations retain Pretendard, real durations/counts, the current four-step form, native controls/chrome, accessible touch targets, and reset restart guidance. None is a claim of pixel identity.
- `/scheduleEdit/:scheduleId` shares the creation form and its mapped components. Database integration verifies following edits preserve individual overrides. Original form and preparation-edit mappings were also audited; a separate edit-only Figma screen is not invented.
- [Native evidence](../docs/design/review/native-20260925/README.md) records a rebuilt iPhone17/iOS26.5 debug simulator: setup and actual numeric entry; notification/AlarmKit denial and defer; successful Files export of an 811-byte encrypted backup; changing buffer 30→35; importing/decrypting the same backup; restoring buffer to 30; reset; and full relaunch to Welcome. The external backup file's hash remained unchanged after reset. This also verifies the repaired iOS export bridge and import UTI boundary in production UI.
- The final full-suite and coverage receipt has one authoritative location: [final combined validation](../docs/design/review/completion-20260925.md#final-combined-validation). Do not reuse the old checkpoint's test/coverage totals or treat targeted passes as the final combined result.

## Explicitly outside the completed app mapping

The manifest's **11 unmapped `design_only_nodes`** are standalone Schedule Detail screens, with no matching app route/implementation. They are different from the existing expandable Calendar card: Upcoming, PreparationDue, Preparing, CompletedOnTime, CompletedLate, CompletedUnknown, PastUnrecorded, Loading, Refreshing, NotFound, and Failure. Their node IDs and audit evidence are in [the Calendar report](../docs/design/review/calendar-parity-20260925.md#unmapped-full-schedule-detail-design-audit). Strict app coverage does not certify or implement them; adding that product flow is separate work.

## Remaining release acceptance

1. Local final combined validation is complete and recorded in the completion report. Read the current PR head and its remote checks before merge; keep local execution and remote CI receipts distinct.
2. Attach an available physical iPhone and execute device font/layout inspection, VoiceOver interaction, background/locked-screen alarm delivery, and scrolling/frame-time measurements. All paired devices were unavailable during this task; debug simulator rendering is not a device performance result.
3. Keep native evidence scoped accurately. The 2026-09-25 run proves the setup/permission denial/data lifecycle above. Export cancellation has automated coverage, not an executed native cancellation receipt. Appointment creation/edit/delete and recurring scope/conflict/ownership use widget/database integration; earlier native recurring evidence retains its own date. Successful alarm delivery was not observed in this run.
4. Preserve Draft PR #596 until the required release gates and normal review are satisfied. No merge or release was performed by this documentation handoff.
