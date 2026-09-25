# A08 implementation preflight

## Verified starting point

- Baseline source C01 commit `4529d9f84e911b1ee2fbb42af09698a0c27cc9f2`; delivery head `aa2fda68fbf3ac431738de3792f5d587d35b6dda`.
- C01 local959 tests, app-owned88.74%, analyzer and policy gates passed. Remote Flutter35949254397 / Android35949254443 in progress at initial read-back.
- C01 does not yet connect schedule FormSubmission, verified staging/runtime replacement or damaged DB restore. #600 remains open.
- Dedicated implementation agent `/root/implement_a08` owns product/test/generator execution. Root owns issues/state/shared audit documents and GitHub writes.

## Confirmed implementation decisions

1. Reuse actual existing recurring transactions. General schedule/place/preparation/revision commits atomically, protected fields/ownership preserved, read snapshots consistent. Connect C01 typed durable/delivery results to actual FormSubmission/UI.
2. Schema3 additive aggregate incarnation/version/last intent+input digest, local aggregate records rather than global ledger. Actual v1→3 and v2→3 migration and backup1/2 compatibility are acceptance criteria. Internal receipts are not exported in backup2.
3. Recurring series root segment owns create/following receipt, per-occurrence Schedule plus root version changes atomically for occurrence edits. Pure new materialization does not increment user mutation version. Existing occurrence changes affect stale baselines.
4. New-create absent-target baseline uses durable revision fence; a concurrent unrelated durable edit can require explicit review/new intent while preserving the draft. Edit uses aggregate version, not global revision. No silent baseline refresh.
5. Root verified current restore uses backup revision+1, so monotonic installation revision was a false assumption and explicitly withdrawn. A new persisted store incarnation on Local Profile is stable across process restart/ordinary profile writes and reissued at actual restore/reset creation. It is excluded from backup. Draft/receipt compare store plus aggregate incarnation. Future A09/D02 profile-preserving replacement must reissue it.

## Validation and evidence

- Reproduce current partial-write failure with actual Drift, preserve negative proof, then use deterministic rollback/barriers/reader snapshots and UI result assertions.
- Same-intent pending/replay, commit-receipt loss+new instance, create/delete/old retry, split/removal, ABA, old store with same revision, unrelated edits, partial delivery retry all require actual tests.
- Native OS awaits never run inside DB transaction. Strict local-only and ignored generated policy remain.
- Implementation agent preserves full actual questions/answers/corrections in `/tmp/a08-review-transcript.md`; root appends them to #601 with source and exact verification receipts.
- Source freeze/hash before final suite, whole tests/coverage, analyzer and appropriate gates. Root independently reviews and verifies committed blobs. Missing physical/device/remaining dependency evidence stays pending; no false issue close.

## Publication limitation

PR585 body edit was rejected by auto-review for lack of explicit authorization for that body/destination. Approval question remains unanswered. Frozen approval payload is `/tmp/ontime-audit-pr.md` (SHA256 `107246ced5bc0a88cff9f191ccdefcd5d89373c873fb28e92af46402d45d9d41`). Do not retry or publish via another path. Detailed issues and implementation continue under user authorization.
