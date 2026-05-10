# Backend Account Deletion Retention Report

Date: 2026-05-10
Related issues: #434, #439, #440, #441, #458
Audience: OnTime backend and environment owners

## Purpose

This report asks backend owners to confirm and, if needed, implement the
retention behavior that the OnTime privacy policy draft now states. The goal is
to keep the privacy policy, Google Play Data safety answers, backend behavior,
and account deletion QA aligned.

## Proposed Retention Policy

Use these retention periods unless product/legal owners later require a stricter
policy:

| Data category | Retention after account deletion | Reason |
| --- | --- | --- |
| Local OnTime account row | Delete immediately | Account deletion request |
| User-owned app data, including schedules, preparation data, notification schedules, user settings, alarm settings, alarm status, device records, FCM tokens, and session tokens | Delete immediately by database cascade or equivalent cleanup | Account deletion request |
| General feedback linked to the user account | Delete immediately by database cascade or equivalent cleanup | Account deletion request |
| Optional account deletion feedback | Retain for up to 1 year | Service quality review and deletion-related support issues |
| Operational logs, monitoring records, and security records | Retain for up to 90 days | Service operation, debugging, security, and abuse prevention |
| Database backups or disaster recovery snapshots | Retain for no longer than 30 days under normal backup rotation | Disaster recovery |
| Legal, compliance, or active security investigation records | Retain only as long as required for the legal/compliance/investigation purpose | Legal compliance or active security investigation |

## Backend Confirmation Needed

Before #434 privacy policy approval, backend/environment owners should confirm:

- The account deletion endpoints still hard-delete the local OnTime account row.
- Database cascades or explicit cleanup remove associated user-owned app data.
- Optional account deletion feedback is stored separately from the deleted user
  account and does not contain plaintext email.
- There is, or will be, a cleanup mechanism that deletes
  `account_deletion_feedback` rows older than 1 year.
- Production application logs, hosting logs, monitoring events, analytics,
  audit records, and security records do not retain account-related data for
  more than 90 days unless an exception applies.
- Database backups and snapshots are rotated out within 30 days unless an
  exception applies.
- Any exception is documented with data category, reason, owner, and maximum
  retention duration.
- Google and Apple provider token revocation remains best-effort unless release
  environment testing proves a stronger guarantee.

## Recommended Backend Tasks

1. Add retention cleanup for account deletion feedback.
   - Target table: `account_deletion_feedback`
   - Target rule: delete rows where `created_at` is older than 1 year.
   - Recommended verification: unit or integration test for cleanup cutoff.

2. Confirm production logging retention.
   - Target rule: logs, monitoring records, and security records retained for
     up to 90 days.
   - Recommended verification: screenshot, config export, or written owner
     confirmation from the logging/hosting provider.

3. Confirm backup retention.
   - Target rule: database backups and disaster recovery snapshots retained for
     no longer than 30 days under normal rotation.
   - Recommended verification: backup policy document, provider setting, or
     written owner confirmation.

4. Document exceptions.
   - If legal compliance, abuse prevention, or active investigation requires
     longer retention, record the data category, reason, owner, and maximum
     retention period.
   - Do not use open-ended language such as "as needed" without a defined owner
     and review trigger.

5. Send release evidence back to frontend/release owners.
   - Update #434 when the privacy policy wording is accurate.
   - Update #441 so the Google Play Data safety form can reflect the same
     deletion and retention behavior.
   - Update #458 so account deletion QA knows which retained data is expected.

## Draft Privacy Policy Wording

The frontend privacy policy draft currently uses this retention language:

```text
When a user deletes their OnTime account, OnTime deletes the local account and
associated app data, including schedules, preparation data, notification
schedules, user settings, alarm settings, alarm status, device records, FCM
tokens, and session tokens.

If the user submits optional account deletion feedback, OnTime may retain that
feedback for up to 1 year to review service quality and deletion-related support
issues. This feedback is stored separately from the deleted account and uses a
hashed email value instead of the plaintext email address.

Operational logs, monitoring records, and security records may be retained for
up to 90 days for service operation, debugging, security, and abuse-prevention
purposes, unless a longer period is required for legal compliance or an active
security investigation.

Backup copies containing deleted account data are removed according to the
normal backup rotation and are retained for no longer than 30 days, unless a
longer period is required by law or security investigation.
```

Backend owners should either confirm this language or propose exact replacement
wording before #434 is approved.

## Policy References

- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play account deletion requirements:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play Data safety form guidance:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Korea Personal Information Protection Commission privacy guidance:
  https://www.pipc.go.kr/eng/user/cmm/privacyGuideline.do
